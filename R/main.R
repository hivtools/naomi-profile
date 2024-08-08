docopt_parse <- function(usage, args) {
  dat <- docopt::docopt(usage, args)
  names(dat) <- gsub("-", "_", names(dat), fixed = TRUE)
  dat
}

main_fit_model_args <- function(args = commandArgs(TRUE)) {
  usage <- "Usage:
fit_model (--output-zip=<path>)
fit_model -h | --help

Options:
-h --help            Show this screen
--output-zip=<path>  Path to model output zip"
  dat <- docopt_parse(usage, args)
  list(output_zip = dat$output_zip)
}

main_fit_model <- function(args = commandArgs(TRUE)) {
  args <- main_fit_model_args(args)
  out <- unzip_and_fetch_debug(args$output_zip)

  files <- lapply(out$state$datasets, function(dataset) basename(dataset$path))
  files <- lapply(files, function(file) {
    input_path <- file.path(out$debug_path, out$state$model_fit$id, "files", file)
    if (!file.exists(input_path)) {
      stop(sprintf("File at path %s does not exist", input_path))
    }
    input_path
  })

  out_path <- tempfile()
  dir.create(out_path, TRUE, FALSE)
  withr::with_envvar(c("USE_MOCK_MODEL" = "false"), {
    model_run <- hintr:::run_model(files, out$state$model_fit$options, out_path)
  })
}
