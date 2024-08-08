# naomi-profile

We want to monitor the memory usage of Naomi model fit so we can plan what resources we need when we run the app on azure. This can be quite challenging! There are two types of profiling
1. Using build in R memory profiler
2. Using a sampling profiler, inside or outside of R

## R memory profiler

R has a memory profiler built into the language. There are a few packages which make interacting with it a bit easier such as `profmem`. These work by logging all memory allocations that are done via the native `allocVector3()` part of R's native API. Which should be most of them. Any objects allocated this way are automatically deallocated by R's garbage collector at some point, but these are not logged. It also doesn't log any allocations done by non-R native libraries or R packages that use native code for internal objects. I'm not sure if this will include TMB allocated objects or not, but since this is only showing allocations the peak will be much higher for TMB than the actual peak memory used.

## Sampling profiler

There are many of these available
* `memprof` - R package I wrote for doing this within R, though I am not sure how good this is. I get good results when running TMB which match other profilers I've used but I see weird results with any output generation. I think this needs a bit of work.
* Monitoring it from the command line with `ps` or `top`
* With `valgrind`s tool `massif`, this probably gives the most accurate results but is much slower to run

# Prerequisites

* You're on a linux machine
* naomi is installed
* hintr is instaled
* valgrind is installed
* You can pull download debug files from Naomi
* You have 23/24 model fits available on disk (could set up programmatic pulling of these later)

# Scripts

This repo provides some scripts we can re-use for profiling parts of naomi. The rough approach this uses is. The scripts use the approved model fits from 2023/24, pull the relevant files from the server and then fit the model using the same files and model options they used. This should hopefully give a reliable result for most countries.

1. fit_model - takes path to the output zip. Note quoting to work around issues with docopt and spaces in strings
   ```sh
   ./fit_model '"~/Downloads/ESW 2024 naomi_outputs.zip"'
   ```
2. calibrate_fit - takes path to the output zip
   ```sh
   ./calibrate_fit '"~/Downloads/ESW 2024 naomi_outputs.zip"'
   ```
3. generate_output - takes download type and path to the output zip
   ```sh
   ./generate_output --type=spectrum '"~/Downloads/ESW 2024 naomi_outputs.zip"'
   ```
   download types are `spectrum`, `coarse`, `summary`, `comparison` and `agyw` 

Then you can add profiler to these

1. massif - will output a massif.out files with the ISO3 and PID
2. memusg - credit https://gist.github.com/netj/526585

### Usage

To profile model fit with valgrind massif
```sh
./profilers/massif --label ESW fit_model '"~/Downloads/ESW 2024 naomi_outputs.zip"'
```
This will produce a file `out/massif.ESW.$TIME`

You can then view the memory usage graph and all details with `ms_print` or the wrapper function here
```shell
./printer/ms_print ./out/massif.ESW.$PID
```

To profile calibration with memusg. Note be careful with quoting
```sh
./profilers/memusg --label ESW ./calibrate_fit '"~/Downloads/ESW 2024 naomi_outputs.zip"'
```

This will output a file `memusg.ESW.$TIME`, view the result by printing it.
