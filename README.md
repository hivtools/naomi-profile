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
* hintr is installed
* valgrind is installed
* You can pull download debug files from Naomi
* You have 23/24 model fits available on disk (could set up programmatic pulling of these later)

# Usage

This repo provides a top level script which will profile model fit and calibration fit for a range of countries using your specified profiler. You might also have to update the file paths in the script, these are specific to my machine. Ideally would put this as an arg but will do that if someone else tries to run this at some point.

1. Fetch debug output `./fetch_debugs <path>` where the path is a path to a Naomi output zip. Note this must be an output zip created on the production application. `fetch_debugs` will pull all Naomi web app debugs for this output. This will save the outputs to a dir `debug` relative to where you ran the script from.
2. Run the profile, edit the list of countries to run the profile for in the `profile` script. Here https://github.com/hivtools/naomi-profile/blob/2e6cfc9467587fe5205a9512846ef53bd43466d4/profile#L82 (I should put this into an argument down the line)

   To profile using massif
   ```sh
   ./profile --profiler ./profilers/massif
   ```

   To profile using memusg
   ```sh
   ./profile --profiler ./profilers/memusg
   ```

   Output will be written to `out` directory. Any failed runs will still be profiled but with a `.FAILED` prefix on their filename.

   You can supply your own profiler too, it needs to be a script which takes a named `--label` arg and then the name of script to profile and any args to that script. See section below for more details.

3. Summarise all the results
   ```sh
   ./summarise --type memusg out
   ```
4. If you want to run more profiles perhaps comparing branches, I would recommend moving the `out` directory to something with a better name before you run a 2nd time because otherwise outputs from the 2 profiles will be in the same directory.

## Individual scripts

This repo provides some scripts we can re-use for profiling parts of naomi. The rough approach this uses is. The scripts use the approved model fits from 2023/24, pull the relevant files from the server and then fit the model using the same files and model options they used. This should hopefully give a reliable result for most countries.

1. fit_model - takes path to the output zip. Note quoting to work around issues with docopt and spaces in strings
   ```sh
   ./fit_model '"~/Downloads/ESW 2024 naomi_outputs.zip"'
   ```
2. calibrate_fit - takes path to the output zip
   ```sh
   ./calibrate_fit '"~/Downloads/ESW 2024 naomi_outputs.zip"'
   ```
   This can optionally save out calibration results to a directory, which can then be used for profiling download later.
   ```sh
   ./calibrate_fit '"~/Downloads/ESW 2024 naomi_outputs.zip"' results
   ```
3. generate_download - takes download type and path to the output zip
   ```sh
   ./generate_download results/SWZ_1ac27f5e578eb4dc087e7a90ff5a72b5_20240809_140633 spectrum
   ```
   download types are `spectrum`, `coarse_output`, `summary`, `comparison` and `agyw` 

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


## Future work

* Add some plots into summary
* Remove the weird extra layer of file creation from calibrate
* Remove differences in naming between running `./profile` and running separately
