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
