using CSV
using DataFrames

function meanmass(xs)
    xs1 = filter(skipmissing(xs)) do x
        x > 0
    end
    if length(xs1) > 0
        mean(xs1)
    else
        missing
    end
end

function load_mass_traits(s, datasets;
    weigelt_csv,
    heinen_csv,
)

    heinen_mass = CSV.read(heinen_csv, DataFrame;
        missingstring="NA", types=Dict(:Mean_Body_Mass_Heinen_gram => Float64)
    ) |> x -> select(x, [:GBIFSpecies, :Mean_Body_Mass_Heinen_gram])

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

    s_mass = leftjoin(s, mean_mass_df; on=:GBIFSpecies, matchmissing=:notequal, makeunique=true) |>
         x -> leftjoin(x, genus_mean_mass_df; on=:Genus, matchmissing=:notequal) |>
         x -> leftjoin(x, heinen_mass; on=:GBIFSpecies)

    class_means = map(collect(groupby(s_mass, :className))) do group
        union(group.className)[1] => exp(mean(log.(skipmissing(group.Mass_mean))))
    end |> Dict

    s_mass.EstimatedMass = map(s_mass.className, s_mass.Mass_mean, s_mass.Genus_mass_mean, s_mass.Mean_Body_Mass_Heinen_gram, s_mass.LiteratureMass) do class, mm, gm, hm, lm
        # First check dataset species mean
        x = if ismissing(mm) || isnan(mm)
            # Then check mass manually taken from the literature
            if ismissing(lm)
                # Then Heinen, otherwise use genus mean
                ismissing(hm) ? gm : hm
            else
                lm
            end
        else
            mm
        end
        if (ismissing(x) || isnan(x))
            missing
            # Generate random gapfil data until there are no missing masses
            # class_means[class]
        else
            x
        end
    end;

    s_mass.EstimatedMass |> skipmissing |> collect |> length
    s_mass.colonised = map(s_mass.ArchipelagoColonised, s_mass.LocationColonised) do a, i
        ismissing(i) ? a : i
    end
    s_mass.isisland = s_mass.Island .== "Yes"
    s_mass.wasuninhabited = map(s_mass.ArchipelagoPreviouslyInhabited .== ("No",), s_mass.LocationPreviouslyInhabited .== ("No",)) do a, i
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
    s_mass.yearLastSeen_cleaned .= ((x, c) -> ismissing(x) ? c : x).(s_mass.yearLastSeen_cleaned, s_mass.colonised)

    weigelt_islands = CSV.read(weigelt_csv, DataFrame)

    s_weigelt = leftjoin(s_mass, weigelt_islands; on=:WeigeltID=>:ID, matchmissing=:notequal, makeunique=true)
    s1 = dropmissing(s_weigelt, [:colonised, :EstimatedMass, :yearLastSeen_cleaned])
    return (; s1, mean_mass_df)
end
