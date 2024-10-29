# Species
function get_flat_threats(threats_dict)
    threatkeys = nothing
    for (k, v) in threats_dict
        if length(v) > 0
            threatkeys = Tuple(Symbol.(keys(v[1])))
        end
    end
    isnothing(threatkeys) && return missing
    allkeys = (:name, threatkeys...)
    map(collect(pairs(threats_dict))) do (k, v)
        map(v) do threat
            as_missings = map(v -> isnothing(v) ? missing : v, values(threat))
            NamedTuple{allkeys}((k, ntuple(i -> as_missings[i], 7)...))
        end
    end |> Iterators.flatten |> collect |> DataFrame
end

function get_threat_groups(df, datapath)
    iucn_threats_json_path = joinpath(datapath, "iucn_threats.json")
    iucn_threats_dict = JSON3.read(iucn_threats_json_path, Dict{String,Any})

    flat_threats = get_flat_threats(iucn_threats_dict)
    # Attach ICUN data to threats records with a left join
    # TODO some rows added here with leftjoin
    flat_threats_with_assesment = leftjoin(flat_threats, df;
        on=:name => :scientificName
    )
    grouped_codes = Dict{String,Vector{Int}}()

    allcodes = union(flat_threats_with_assesment.name .=> parse.(Int, first.(split.(flat_threats_with_assesment.code, '.'))))
    for (k, v) in allcodes
        if haskey(grouped_codes, k)
            push!(grouped_codes[k], v)
        else
            grouped_codes[k] = [v]
        end
    end
    return map(df.scientificName) do name
        get(grouped_codes, name, Int[])
    end
end

function get_threat_codes(df, datapath)
    iucn_threats_json_path = joinpath(datapath, "iucn_threats.json")
    iucn_threats_dict = JSON3.read(iucn_threats_json_path, Dict{String,Any})

    flat_threats = get_flat_threats(iucn_threats_dict)
    # Attach ICUN data to threats records with a left join
    # TODO some rows added here with leftjoin
    flat_threats_with_assesment = leftjoin(flat_threats, df;
        on=:name => :scientificName
    )
    grouped_codes = Dict{String,Vector{String}}()

    for (k, v) in zip(flat_threats_with_assesment.name, flat_threats_with_assesment.code)
        if haskey(grouped_codes, k)
            push!(grouped_codes[k], v)
        else
            grouped_codes[k] = String[v]
        end
    end
    return map(df.scientificName) do name
        get(grouped_codes, name, String[])
    end
end

function plot_threat_density!(ax, df;
    normalise=false, classes, colors
)
    threat_groups = map(1:12) do threat_code
        subset(df,
            :className => ByRow(in(classes)),
            :threat_groups => ByRow(tcs -> threat_code in tcs),
        )
    end
    labels = ["Invasives", "Human hunting", "Land cover change", "Other",]
    group_queries = (
        :threat_codes => ByRow(x -> any(c -> c in x, INVASIVE_CAUSED)),
        :threat_codes => ByRow(x -> any(c -> c in x, HUMAN_CAUSED)),
        :threat_codes => ByRow(x -> any(c -> c in x, LCC_CAUSED)),
        :threat_codes => ByRow(x -> any(c -> c in x, OTHER_CAUSED)),
    )
    groups = map(group_queries) do q
        subset(df, q)
    end
    upper = nothing
    # group = threat_groups[a]
    all_years = collect(skipmissing(df.yearLastSeen_cleaned))
    kde_kw = (; boundary=(1350, 2025), npoints=2025-1350+1, bandwidth=25)
    u_all = kde(all_years; kde_kw...)
    group_stats = map(groups) do group
        years = collect(skipmissing(group.yearLastSeen_cleaned))
        u = kde(years; kde_kw...)
        adjusted_density = u.density .* length(years)
        if isnothing(upper)
            upper = adjusted_density
            lower = adjusted_density .* 0
        else
            lower = upper
            upper = upper .+ adjusted_density
        end
        (; lower, upper, kde=u)
    end
    group_stats = map(group_stats) do (; lower, upper, kde)
        if normalise
            (;
                lower=lower ./ last(group_stats).upper .- 0.001,
                upper=upper ./ last(group_stats).upper,
                kde,
            )
        else
            (;
                lower=lower .- 0.001,
                upper=upper,
                kde,
            )
        end
    end
    length(group_stats)
    i = 2
    for i in reverse(eachindex(groups))
        s = group_stats[i]
        Makie.band!(ax, s.kde.x, s.lower, s.upper;
            label=string(labels[i]),
            color=(colors[i], 0.95),
            # strokecolor=get(colors, i/length(selected_threats)), p2_kw...
        )
    end
    if !normalise
        axislegend(ax;
            position=(0.1, normalise ? 0.1 : 0.9),
            framevisible=false,
        )
    end
    scatter!(ax, all_years, map(_ -> 0.0, all_years);
         markersize=30,
         marker=:vline,
         color=(:black, 0.30),
    )
    return ax
end
