
function load_mass_traits(df, datasets)
    # Open all csvs as DataFrames
    trait_dfs = map(trait_csvs) do props
        df = CSV.read(props.csv, DataFrame; types=Dict(props.mass => Float64))
        merge((; df), props)
    end
    trait_dfs.mascarene.df.Family

    # Make sure to update all the names from GBIF
    map(trait_dfs, keys(trait_dfs)) do props, key
        if :GBIFSpecies in names(props.df)
            set_gbif_species!(props.df, props.binomial)
        else
            props.df.GBIFSpecies .= getproperty(props.df, props.binomial)
        end
    end

    # Combined all the trait dataframes into one
    mega_mass_df = map(trait_dfs, keys(trait_csvs)) do (; df, mass, binomial), db
        df.Database .= db
        # Standardize mass column
        dropmissing(select(df, :GBIFSpecies, binomial => :OriginalBinomial, mass => :Mass, :Database))
    end |> splat(vcat) |> sort

    # Split and combine taking the mean, will tracking the source databases
    mean_mass_df = DataFrames.combine(
        groupby(mega_mass_df, :GBIFSpecies),
        [:Mass => meanmass => :Mass_mean, :Database => Tuple => :Mass_sources],
    ) |> sort

    # Split out the Genus field to another column
    mean_mass_df.Genus = map(mean_mass_df.GBIFSpecies) do s
        ismissing(s) ? missing : split(s, ' ')[1]
    end
    s.Genus = map(s.GBIFSpecies) do s
        ismissing(s) ? missing : split(s, ' ')[1]
    end

    genus_mean_mass_df = DataFrames.combine(
        groupby(mean_mass_df, :Genus),
        [:Mass_mean => meanmass => :Genus_mass_mean, :Mass_sources => Tuple => :Genus_mass_sources],
    ) |> sort

    df_mass = leftjoin(df, mean_mass_df; on=:GBIFSpecies, matchmissing=:notequal, makeunique=true) |>
         x -> leftjoin(x, genus_mean_mass_df; on=:Genus, matchmissing=:notequal)

    class_means = map(collect(groupby(df_mass, :className))) do group
        union(group.className)[1] => exp(mean(log.(skipmissing(group.Mass_mean))))
    end |> Dict

    # Choose mass source depending on what is available
    df_mass.EstimatedMass = map((mass_df.Mass_mean, mass_df.Genus_mass_mean, mass_df.LiteratureMass)) do mm, gm, lm
        # First check dataset species mean
        x = if ismissing(mm) || isnan(mm)
            # Then check mass manually taken from the literature, otherwise use the genus mean
            ismissing(lm) ? gm : lm
        else
            mm
        end
        (ismissing(x) || isnan(x)) ? missing : x
    end;

    df_mass.EstimatedMass |> skipmissing |> collect |> length
    df_mass.colonised = map(df_mass.ArchipelagoColonised, df_mass.LocationColonised) do a, i
        ismissing(i) ? a : i
    end
    df_mass.isisland = df_mass.Island .== "Yes"
    df_mass.wasuninhabited = map(df_mass.ArchipelagoPreviouslyInhabited .== ("No",), df_mass.LocationPreviouslyInhabited .== ("No",)) do a, i
        if ismissing(a)
            if ismissing(i)
                false
            else
                i
            end
        elseif ismissing(i)
            a
        else
            a || i
        end
    end
    # Backfill missing last seen years with colonised years
    df_mass.yearLastSeen_cleaned .= ((x, c) -> ismissing(x) ? c : x).(df_mass.yearLastSeen_cleaned, df_mass.colonised)

    return (; df_mass, mean_mass_df)
end

# Calculate the mean mass of a column,
# being careful to skip missings and zero values
# If there is nothing left we return missing, otherwise the mean
function meanmass(xs)
    xs_cleaned = filter(skipmissing(xs)) do x
        x > 0
    end
    return isempty(xs_cleaned) ? missing : mean(xs_cleaned)
end
# Add weigelt IDs
# Not actually used yet, but allows island size/distance analysis
function add_weigelt!(df)
    weigelt_islands = CSV.read(weigelt_csv, DataFrame)
    df_weigelt = leftjoin(df, weigelt_islands; on=:WeigeltID=>:ID, matchmissing=:notequal, makeunique=true)
end
