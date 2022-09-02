function montecarlo(config::Configuration, integrand::Function, neval, userdata, print, save, timer;
    measurefreq=2, measure::Union{Nothing,Function}=nothing, kwargs...)
    ##############  initialization  ################################
    # don't forget to initialize the diagram weight

    for i in 1:10000
        initialize!(config, integrand, userdata)
        if (config.curr == config.norm) || abs(config.absWeight) > TINY
            break
        end
    end
    @assert (config.curr == config.norm) || abs(config.absWeight) > TINY "Cannot find the variables that makes the $(config.curr) integrand >1e-10"

    # weight = config.curr == config.norm ? 1.0 : integrand_wrap(config, integrand, userdata)
    # setweight!(config, weight)
    # config.absWeight = abs(weight)


    # updates = [changeIntegrand,] # TODO: sample changeVariable more often
    # updates = [changeIntegrand, swapVariable,] # TODO: sample changeVariable more often
    updates = [changeIntegrand, swapVariable, changeVariable] # TODO: sample changeVariable more often
    for i = 2:length(config.var)*2
        push!(updates, changeVariable)
    end

    ########### MC simulation ##################################
    # if (print > 0)
    #     println(green("Seed $(config.seed) Start Simulation ..."))
    # end
    startTime = time()

    for i = 1:neval
        config.neval += 1
        config.visited[config.curr] += 1
        _update = rand(config.rng, updates) # randomly select an update
        _update(config, integrand, userdata)
        # push!(kwargs[:mem], (config.curr, config.relativeWeight))
        # if i % 10 == 0 && i >= neval / 100
        if i % measurefreq == 0 && i >= neval / 100

            ######## accumulate variable #################
            if config.curr != config.norm
                for (vi, var) in enumerate(config.var)
                    offset = var.offset
                    for pos = 1:config.dof[config.curr][vi]
                        Dist.accumulate!(var, pos + offset, 1.0)
                    end
                end
            end
            ###############################################

            if config.curr == config.norm # the last diagram is for normalization
                config.normalization += 1.0 / config.reweight[config.norm]
            else
                if isnothing(measure)
                    config.observable[config.curr] += config.relativeWeight
                else
                    if isnothing(userdata)
                        measure(config.observable, config.relativeWeight; idx=config.curr)
                    else
                        measure(config.observable, config.relativeWeight; idx=config.curr, userdata=userdata)
                    end
                end
            end
        end
        if i % 1000 == 0
            for t in timer
                check(t, config, neval)
            end
        end
    end

    # if (print > 0)
    #     println(green("Seed $(config.seed) End Simulation. Cost $(time() - startTime) seconds."))
    # end

    return config
end


@inline function integrand_wrap(config, _integrand, userdata, signal=nothing)
    if length(config.dof) - 1 == 1 # there is only one integral (plus a normalization integral)
        if !isnothing(userdata) && !isnothing(signal)
            return _integrand(config.var...; userdata=userdata, signal=signal)
        elseif !isnothing(userdata)
            return _integrand(config.var...; userdata=userdata)
        elseif !isnothing(signal)
            return _integrand(config.var...; signal=signal)
        else
            return _integrand(config.var...)
        end
    else
        if !isnothing(userdata) && !isnothing(signal)
            return _integrand(config.var...; userdata=userdata, idx=config.curr, signal=signal)
        elseif !isnothing(userdata)
            return _integrand(config.var...; userdata=userdata, idx=config.curr)
        elseif !isnothing(signal)
            return _integrand(config.var...; signal=signal, idx=config.curr)
        else
            return _integrand(config.var...; idx=config.curr)
        end
    end
end

function initialize!(config, integrand, userdata)
    for var in config.var
        Dist.initialize!(var, config)
    end

    weight = config.curr == config.norm ? 1.0 : integrand_wrap(config, integrand, userdata)
    setweight!(config, weight)
    config.absWeight = abs(weight)
end

function setweight!(config, weight)
    config.relativeWeight = weight / abs(weight) / config.reweight[config.curr]
end


function doReweight!(config, alpha)
    avgstep = sum(config.visited)
    for (vi, v) in enumerate(config.visited)
        # if v > 1000
        if v <= 1
            config.reweight[vi] *= (avgstep)^alpha
        else
            config.reweight[vi] *= (avgstep / v)^alpha
        end
    end
    config.reweight .*= config.reweight_goal
    # renoormalize all reweight to be (0.0, 1.0)
    config.reweight ./= sum(config.reweight)
    # avoid overreacting to atypically large reweighting factor
    # reweighting factor close to 1.0 will not be changed much
    # reweighting factor close to zero will be amplified significantly
    # Check Eq. (19) of https://arxiv.org/pdf/2009.05112.pdf for more detail
    # config.reweight = @. ((1 - config.reweight) / log(1 / config.reweight))^beta
    # config.reweight ./= sum(config.reweight)
end

# function doReweight!(config, alpha)
#     avgstep = sum(config.visited) / length(config.visited)
#     for (vi, v) in enumerate(config.visited)
#         if v > 1000
#             config.reweight[vi] *= avgstep / v
#             if config.reweight[vi] < 1e-10
#                 config.reweight[vi] = 1e-10
#             end
#         end
#     end
#     # renoormalize all reweight to be (0.0, 1.0)
#     config.reweight .= config.reweight ./ sum(config.reweight)
#     # dample reweight factor to avoid rapid, destabilizing changes
#     # reweight factor close to 1.0 will not be changed much
#     # reweight factor close to zero will be amplified significantly
#     # Check Eq. (19) of https://arxiv.org/pdf/2009.05112.pdf for more detail
#     config.reweight = @. ((1 - config.reweight) / log(1 / config.reweight))^2.0
# end