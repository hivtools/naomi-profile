docopt_parse <- function(usage, args) {
  dat <- docopt::docopt(usage, args)
  names(dat) <- gsub("-", "_", names(dat), fixed = TRUE)
  dat
}

main_fit_model_args <- function(args = commandArgs(TRUE)) {
  usage <- "Usage:
fit_model (<path>)
fit_model -h | --help

Options:
-h --help  Show this screen
<path>     Path to model output zip"
  dat <- docopt_parse(usage, args)
  list(output_zip = dat$path)
}

main_fit_model <- function(args = commandArgs(TRUE)) {
  args <- main_fit_model_args(args)
  out <- unzip_and_fetch_debug(args$output_zip)

  files <- lapply(out$state$datasets, function(dataset) basename(dataset$path))
  files <- lapply(files, function(file) {
    input_path <- file.path(out$debug_path, out$id, "files", file)
    if (!file.exists(input_path)) {
      stop(sprintf("File at path %s does not exist", input_path))
    }
    input_path
  })

  out_path <- tempfile()
  dir.create(out_path, TRUE, FALSE)
  message("Fitting model")
  withr::with_envvar(c("USE_MOCK_MODEL" = "false", "OMP_NUM_THREADS" = "1"), {
    model_run <- hintr:::run_model(files, out$state$model_fit$options, out_path)
  })
  message("Model fit complete")
}

main_calibrate_args <- function(args = commandArgs(TRUE)) {
  usage <- "Usage:
calibrate_fit (<path>) [<output-dir>]
calibrate_fit -h | --help

Options:
-h --help    Show this screen
<path>       Path to model output zip
<output-dir> Optional, path to save calibration output, for later use to check download generation"
  dat <- docopt_parse(usage, args)
  if (is.null(dat$output_dir)) {
      dat$output_dir <- tempfile()
      dir.create(dat$output_dir)
  }
  list(output_zip = dat$path,
       output_dir = dat$output_dir)
}

main_calibrate_fit <- function(args = commandArgs(TRUE)) {
  args <- main_calibrate_args(args)
  out <- unzip_and_fetch_debug(args$output_zip, "calibrate")

  job_data <- readRDS(file.path(out$debug_path, out$id, "data.rds"))
  model_output <- job_data$variables$model_output

  model_output_path <- list.files(file.path(out$debug_path, out$id, "files"), full.names = TRUE)

  model_output$model_output_path <- model_output_path

  now <- format(Sys.time(), "%Y%m%d_%H%M%S")
  iso3 <- out$state$model_fit$options$area_scope
  dir_results <- file.path(args$output_dir, sprintf("%s_%s_%s", iso3, out$id, now))
  dir.create(dir_results, TRUE, TRUE)
  message("Calibrating model")
  calibrate <- hintr:::run_calibrate(model_output, job_data$variables$calibration_options, dir_results)
  path_output <- file.path(dir_results, "output.rds")
  saveRDS(calibrate, path_output)
  message("Model calibration complete")
}

main_download_args <- function(args = commandArgs(TRUE)) {
  usage <- "Usage:
generate_download (<results-dir>) (<type>)
generate_download -h | --help

Options:
-h --help     Show this screen
<results-dir> Path to results directory to generate download for
<type>        Type of download to create, 'spectrum', 'coarse_output', 'summary', 'comparison' or 'agyw'"
  dat <- docopt_parse(usage, args)
  list(type = dat$type,
       results_dir = dat$results_dir)
}

main_download <- function(args = commandArgs(TRUE)) {
  args <- main_download_args(args)

  output <- readRDS(file.path(args$results_dir, "output.rds"))
  files <- list.files(args$results_dir, full.names = TRUE)
  model_output_path <- files[grepl("*.qs$", files)]
  output$model_output_path <- model_output_path

  res <- tempfile()
  dir.create(res, FALSE, TRUE)

  message(paste("Generating download", args$type))
  input <- NULL
  if (args$type == "spectrum") {
    input <- list(notes = "notes",
                  state = '{"state": "example"}')
  } else if (args$type == "agyw") {
    input <- list(pjnz = "not used")
  }
  download <- hintr:::download(
    output,
    type = args$type,
    path_results = res,
    input = input)
  message(paste("Completed generating download", args$type))
}

unzip_and_fetch_debug <- function(output_zip, stage = "fit") {
  if (!file.exists(output_zip)) {
    stop(sprintf("File at path %s does not exist", output_zip))
  }
  unzip_dir <- tempfile()
  zip::unzip(output_zip, exdir = unzip_dir)

  debug_dest <- tempfile()
  dir.create(debug_dest, TRUE, FALSE)

  state <- jsonlite::read_json(file.path(unzip_dir, "info", "project_state.json"))

  if (stage == "fit") {
    id <- state$model_fit$id
  } else if (stage == "calibrate") {
    id <- state$calibrate$id
  }
  hintr:::download_debug(id, dest = debug_dest)

  list(unzip_path = unzip_dir, debug_path = debug_dest, state = state, id = id)
}
