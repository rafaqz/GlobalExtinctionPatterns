function set_gbif_species!(df::DataFrame, specieskey::Symbol)
    if !("GBIFSpecies" in names(df))
        df.GBIFSpecies .= ""
    end
    specvec = collect(getproperty(df, specieskey))
    for i in eachindex(specvec)
        current = df.GBIFSpecies[i]
        ismissing(current) || current == "" || continue
        sp = specvec[i]
        ismissing(sp) && continue
        match = GBIF2.species_match(sp)
        df.GBIFSpecies[i] = if isnothing(match) || ismissing(match.species)
            specvec[i]
        else
            match.species
        end
    end
end