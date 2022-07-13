
mutable struct SummaryStat
    neval::Int64
    visited::Vector{Float64}
    reweight::Vector{Float64} # only record the reweight factor of a typical configuration
    propose::Array{Float64,3}
    accept::Array{Float64,3}
end

function addStat(config, summary=nothing)
    if isnothing(summary)
        return SummaryStat(config.neval, config.visited, config.reweight, config.propose, config.accept)
    else
        summary = deepcopy(summary)
        summary.neval += config.neval
        summary.visited += config.visited
        summary.reweight = config.reweight # only record the newest reweight factor
        summary.propose += config.propose
        summary.accept += config.accept
        return summary
    end
end

# sum SummaryStat from all workers to the root
function reduceStat(summary, root, comm)
    neval = MPI.Reduce(summary.neval, MPI.SUM, root, comm)
    visited = MPI.Reduce(summary.visited, MPI.SUM, root, comm)
    reweight = MPI.Reduce(summary.reweight, MPI.SUM, root, comm)
    propose = MPI.Reduce(summary.propose, MPI.SUM, root, comm)
    accept = MPI.Reduce(summary.accept, MPI.SUM, root, comm)
    if MPI.Comm_rank(comm) == root
        reweight ./= MPI.Comm_size(comm)
        return SummaryStat(neval, visited, reweight, propose, accept)
    else
        return summary
    end
end

function pool(c1::Configuration, c2::Configuration)
    c = deepcopy(c1)
    c.neval += c2.neval
    c.visited += c2.visited
    c.propose += c2.propose
    c.accept += c2.accept
    c.observable += c2.observable
    c.normalization += c2.normalization
    return c
end

function reduceConfig(c::Configuration, root, comm)
    if MPI.Comm_rank(comm) == root
        # reweight ./= MPI.Comm_size(comm)
        # return SummaryStat(neval, visited, reweight, propose, accept)
        rc = deepcopy(c)
        rc.neval = MPI.Reduce(c.neval, MPI.SUM, root, comm)
        rc.visited = MPI.Reduce(c.visited, MPI.SUM, root, comm)
        rc.propose = MPI.Reduce(c.propose, MPI.SUM, root, comm)
        rc.accept = MPI.Reduce(c.accept, MPI.SUM, root, comm)
        rc.observable = MPI.Reduce(c.observable, MPI.SUM, root, comm)
        rc.normalization = MPI.Reduce(c.normalization, MPI.SUM, root, comm)
        return rc
    else
        MPI.Reduce(c.neval, MPI.SUM, root, comm)
        MPI.Reduce(c.visited, MPI.SUM, root, comm)
        MPI.Reduce(c.propose, MPI.SUM, root, comm)
        MPI.Reduce(c.accept, MPI.SUM, root, comm)
        MPI.Reduce(c.observable, MPI.SUM, root, comm)
        MPI.Reduce(c.normalization, MPI.SUM, root, comm)
        return c
    end
end

function MPIreduce(data)
    comm = MPI.COMM_WORLD
    Nworker = MPI.Comm_size(comm)  # number of MPI workers
    rank = MPI.Comm_rank(comm)  # rank of current MPI worker
    root = 0 # rank of the root worker

    if Nworker == 1 #no parallelization
        return data
    end
    if typeof(data) <: AbstractArray
        MPI.Reduce!(data, MPI.SUM, root, comm) # root node gets the sum of observables from all blocks
        return data
    else
        result = [data,]  # MPI.Reduce works for array only
        MPI.Reduce!(result, MPI.SUM, root, comm) # root node gets the sum of observables from all blocks
        return result[1]
    end
end