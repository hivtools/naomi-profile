docopt_parse <- function(usage, args) {
  dat <- docopt::docopt(usage, args)
  names(dat) <- gsub("-", "_", names(dat), fixed = TRUE)
  dat
}

summarise_args <- function(args = commandArgs(TRUE)) {
  usage <- "Usage:
summarise --type=<profile-type> (<dir>)
summarise -h | --help

Options:
-h --help              Show this screen
--type=<profile-type>  Type of profile (memusg or massif)
<dir>                  Path to model output zip"
  dat <- docopt_parse(usage, args)
  list(profile_type = dat$type, dir = dat$dir)
}

main_summarise <- function(args = commandArgs(TRUE)) {
    args <- summarise_args(args)
    summarise_memusg(args$profile_type, args$dir)
}

summarise_memusg <- function(profile_type, dir) {
    library(dplyr)
    library(tidyr)
    library(readr)
    files <- list.files(path = dir)
    success_files <- grep(paste0("^", profile_type, ".*(?<!\\.FAILED)$"), files, value = TRUE, perl = TRUE)
    success_files <- file.path(dir, success_files)
    failed_files <- grep(paste0("^", profile_type, ".*\\.FAILED$"), files, value = TRUE, perl = TRUE)
    types <- c("fit", "calibrate", "spectrum", "coarse_output", "summary", "comparison", "agyw")
    for (type in types) {
        table <- process_files(profile_type, success_files, type)
        print_table(table, caption = type)
    }

    failed_table <- failed_files %>%
        tibble(file = .) %>%
        separate(file, c("prefix", "step", "iso3", "timestamp", "status"), sep = "\\.", remove = FALSE) %>%
        count(iso3, name = "failed_count")
    print(failed_table)
}

process_files <- function(profile_type, files, step) {
    if (profile_type == "memusg") {
        read_fun <- read_mem_usage
    } else if (profile_type == "massif") {
        read_fun <- read_massif
    } else {
        stop(paste0("Invalid profile type ", profile_type))
    }
    files %>%
        tibble(file = .) %>%
        mutate(
            filename = basename(file)
        ) %>%
        separate(filename, c("prefix", "step", "iso3", "timestamp"), sep = "\\.", remove = FALSE) %>%
        filter(step == !!step) %>%
        group_by(iso3) %>%
        summarise(
            mem_kb = mean(vapply(file, read_fun, numeric(1)), na.rm = TRUE),
            file_count = n()
        ) %>%
        mutate(
            mem_human = vapply(mem_kb, format_size, character(1))
        ) %>%
        ungroup() %>%
        arrange(desc(mem_kb))
}

read_mem_usage <- function(file_path) {
    as.numeric(readLines(file_path, n = 1))
}

read_massif <- function(file_path) {
    lines <- readLines(file_path)
    mem_heap_line <- grep("mem_heap_B", lines, value = TRUE)
    if (length(mem_heap_line) == 0) {
        message(paste("No mem_heap_B found in file:", file_path))
        return(0)
    }

    memory <- as.numeric(sub(".*=\\s*", "", mem_heap_line))
    peak_memory <- max(memory)
    # massif reports in bytes but memusg in kb, convert this to kb
    as.numeric(peak_memory) / 1e3
}

format_size <- function(x) {
    # Table has memory in KB to convert to bytes before formatting
    utils:::format.object_size(x * 1e3, "auto")
}

print_table <- function(table, caption = NULL) {
    print(knitr::kable(table, caption = caption, format = "simple"))
}
