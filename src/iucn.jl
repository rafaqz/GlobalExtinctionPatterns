const cause_labels = [
    "Residential & commercial"
    "Agriculture & aquaculture"
    "Energy production & mining"
    "Transport corridors"
    "Biological resource use"
    "Human disturbance"
    "Natural system modifications"
    "Invasive & diseases"
    "Pollution"
    "Geological events"
    "Climate & weather"
    "Other options"
]

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
