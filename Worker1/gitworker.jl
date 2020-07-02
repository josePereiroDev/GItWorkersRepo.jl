# This file must be place in the Worker root directory
# inside a git repository. It must be run in a way that
# `worker_dir` point to this file location (by default julia I use @__FILE__ for doing that)

# This script launch all the process that manage the GitWorker

# TODO add installation info here
using GitWorkers
GW = GitWorkers
using Distributed

# ------------------- SET UP -------------------
# This section can be manually modified to match user preferences
# Later you manually must push the changes to the origin, 
# the worker is unable of modifying this file. Do not forget
# to store the configuration key-value pairs in the dict

# the number of workers available for doing tasks
GW.CONFIG["NUM_CPU"] = length(Sys.cpu_info())
GW.CONFIG["NUM_TASK_PROCS"] = GW.CONFIG["NUM_CPU"] - 1 
@assert GW.CONFIG["NUM_TASK_PROCS"] > 1

# Change this to point to this file
GW.CONFIG["WORKER_DIR"] = abspath(@__FILE__) 

# Change this to point to the desired julia executable
# On MacOS it is tipically (set the x to your version)
# /Applications/Julia-1.x.app/Contents/Resources/julia/bin/julia
GW.CONFIG["JULIA_EXE"] = "julia" 
# Julia process execution flags
GW.CONFIG["JULIA_EXEFLAGS"] = "--project='$(Base.current_project())'"
# some checks
GW.check_init()

# ------------------- CREATING PROCESS -------------------
# I must launch all the process at this level. Beside the task process
# the git channel need 3 helper process for functioning, don't wory, they
# must not consume much resorces
GW.CONFIG["MAX_PROCS_NUM"] = GW.CONFIG["NUM_TASK_PROCS"] + 3
addprocs(GW.CONFIG["MAX_PROCS_NUM"];
     exename = GW.CONFIG["JULIA_EXE"], 
     exeflags = GW.CONFIG["JULIA_EXEFLAGS"],
     topology = :master_worker)
@everywhere (using GitWorkers; GW = GitWorkers)
# update config in other process
GW.update_config(GW.CONFIG, workers())
# some checks in all workers
GW.check_init(workers())


# ------------------- START THE LIVE-SAVER LOOP -------------------
# This process will be checking that all is ok.
# Will potentially kill everybody and restart the worker if
# a fatal error occurs.
# TODO: implement this

# ------------------- START THE TASK LAUNCHER LOOP -------------------
# This process will be watching for any runnable task to assign them 
# to an available task process.
remotecall_fetch(GW.start_task_laucher, workers[1], )

