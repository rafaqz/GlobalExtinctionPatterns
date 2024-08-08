using StaticArrays
using Statistics
using StatsBase
using Shapefile
using CSV
using DataFrames
using XLSX
using TerminalPager
using GBIF2
using Loess
using Random
using ColorSchemes

include("rigal.jl")
include("plots.jl")

function set_gbif_species!(df, specieskey)
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


    
# GBIF data

extinctions_csv_path = "/home/raf/PhD/Mascarenes/MauritiusExtinctions/tables/IUCN_extinctions.csv"
extinctions_download = "/home/raf/Downloads/IUCN Extinctions - assessments_gbif.csv"
isfile(extinctions_download) && mv(extinctions_download, extinctions_csv_path; force=true)

classes = ["AMPHIBIA", "AVES", "MAMMALIA", "REPTILIA"]
s = CSV.read(extinctions_csv_path, DataFrame; types=Dict(:LocationColonised=>Int, :ArchipelagoColonised=>Int)) |>
x -> filter(x) do row
    !ismissing(row.kingdomName) &&
    row.kingdomName == "ANIMALIA" &&
    row.className in classes && # No fish or molluscs row.systems != "Marine" && # No marine species like seals or whales
    true
end
set_gbif_species!(s, :scientificName)

# Trait data

# Define all trait dataframes, with key column names
trait_csvs = (;
    atb_anura=(csv="/home/raf/Data/Traits/AmphibianTraitsDatabase/Anura.csv", mass=:SVL, binomial=:Species),
    atb_caudata=(csv="/home/raf/Data/Traits/AmphibianTraitsDatabase/Caudata.csv", mass=:SVL, binomial=:Species),
    atb_gymnophiona=(csv="/home/raf/Data/Traits/AmphibianTraitsDatabase/Gymnophiona.csv", mass=:SVL, binomial=:Species),
    hawaii=(csv="/home/raf/PhD/Mascarenes/MauritiusExtinctions/tables/FE.Case.Tarwater_2020.csv", mass=Symbol("Body.mass_grams"), binomial=:Species),
    mascarene=(csv="tables/mascarene_species.csv", mass=:Mass, binomial=:Species),
    pantheria=(csv="/home/raf/Data/Traits/PanTHERIA/ECOL_90_184/PanTHERIA_1-0_WR05_Aug2008_gbif.csv", mass=:AdultBodyMass_g, binomial=:MSW05_Binomial),
    avonet = (csv="/home/raf/Data/Traits/Avonet/ELEData/ELEData/TraitData/AVONET1_BirdLife_gbif.csv", mass=:Mass, binomial=:Species1),
    # lizzard = (csv="/home/raf/Data/Traits/Lizards/Appendix S1 - Lizard data version 1.0.csv" binomial=:XX),
    elton_mammal = (csv="/home/raf/Data/Traits/EltonTraits/MamFuncDat_gbif.csv", mass=:BodyMass_Value, binomial=:Scientific),
    elton_bird = (csv="/home/raf/Data/Traits/EltonTraits/BirdFuncDat_gbif.txt", mass=:BodyMass_Value, binomial=:Scientific),
    reptile_mass = (csv="/home/raf/PhD/Mascarenes/Tables/Reptile body mass database Meiri 2010_gbif.csv", mass=Symbol("Weight (g)"), binomial=:Name),
    # bird_mass = (csv="/home/raf/PhD/Mascarenes/Tables/Bird Mass filled (Jan 22 2015)_WDK_gbif.csv", mass=:filledmass, binomial=:BirdLife_SpecName),
    frugivores = (csv="tables/Dryad frugivore occurrence database 1-3-17.csv", mass=:Body_mass, binomial=:Species_name),
)

heinen_csv = "/home/raf/PhD/Mascarenes/MauritiusExtinctions/tables/Heinen_extinct_terrestrial_vertebrates.csv"
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

# simplified = select(s_mass, [:scientificName, :GBIFSpecies, :Archipelago, :Location, :Mass_mean, :Genus_mass_mean, :Island])

weigelt_csv = "/home/raf/Data/Extinction/Islands/Weigelt/Weigelt_etal_2013_PNAS_islanddata.csv"
# run(`libreoffice $weigelt_csv`)
weigelt_islands = CSV.read(weigelt_csv, DataFrame)
names(weigelt_islands)

s_colonised = dropmissing(s_mass, :colonised)
s_weigelt = leftjoin(s_colonised, weigelt_islands; on=:WeigeltID=>:ID, matchmissing=:notequal, makeunique=true)
s1 = dropmissing(s_weigelt, [:EstimatedMass, :yearLastSeen_cleaned])
s_no_mass = subset(s_colonised, :EstimatedMass => x -> ismissing.(x))
sort(collect(s_no_mass.Location |> countmap); by=last)

sort(s1.Location |> countmap |> pairs |> collect; by=last)
sort(s1.Archipelago |> countmap |> pairs |> collect; by=last)
sort(s1.SuperArchipelago |> countmap |> pairs |> collect; by=last)
sort(collect(s1.Archipelago |> countmap); by=last)


#  Subsetting

not_mauris = :GBIFSpecies => ByRow(!in(("Chenonetta finschi", "Tribonyx hodgenorum"))
subset_queries = (;
    all=(title="All colonised", query=()),
    islands=(title="All Islands", query=(:isisland,)),
    continents=(title="Continents", query=(:isisland => .!,)),
    inhabited_islands=(title="Inhabited", query=(:isisland, :wasuninhabited => .!,)),
    uninhabited_islands=(title="Uninhabited", query=(:isisland, :wasuninhabited,)),
    indian_ocean=(title="Indian ocean", query=(:SuperArchipelago=>ByRow(==("Indian Ocean")),)),
    mascarenes=(title="Mascarenes", query=(:Archipelago=>ByRow(==("Mascarenes")),)),
    non_mascarene_uninhabited=(title="Non-Mascarene Uninhabited", query=(:isisland, :wasuninhabited, :Archipelago=>ByRow(!=("Mascarenes")),)),
    islands_early=(title="All Early Colonisation", query=(:isisland, :colonised=>ByRow(<(1750)),)),
    islands_late=(title="All Late Colonisation", query=(:isisland, :colonised=>ByRow(>=(1750)),)),
    inhabited_early=(title="Inhabited Early Colonisation", query=(:isisland, :wasuninhabited => .!, :colonised=>ByRow(<(1750)),)),
    inhabited_late=(title="Inhabited Late Colonisation", query=(:isisland, :wasuninhabited => .!, :colonised=>ByRow(>=(1750)),)),
    uninhabited_early=(title="Uninhabited Early Colonisation", query=(:isisland, :wasuninhabited, :colonised=>ByRow(<(1750)),)),
    uninhabited_late=(title="Uninhabited Late Colonisation", query=(:isisland, :wasuninhabited, :colonised=>ByRow(>=(1750)),)),

    australian_continent=(title="Australian Continent", query=(:isisland => .!, :SuperArchipelago=>ByRow(==("Australia")),)),
    australian_islands=(title="Australian Islands", query=(:isisland, :SuperArchipelago=>ByRow(==("Australia")),)),
    australian_inhabited_islands=(title="Australian Inhabited Islands", query=(:isisland, :wasuninhabited => .!, :SuperArchipelago=>ByRow(==("Australia")),)),
    australian_uninhabited_islands=(title="Australian Uninhabited Islands", query=(:isisland, :wasuninhabited, :SuperArchipelago=>ByRow(==("Australia")),)),

    mauritius=(title="Mauritius", query=(:Location=>ByRow(==("Mauritius")),)),
    reunion=(title="Reunion", query=(:Location=>ByRow(==("Reunion")),)),
    rodrigues=(title="Rodrigues", query=(:Location=>ByRow(==("Rodrigues")),)),
    australia=(title="Australia", query=(:SuperArchipelago=>ByRow(==("Australia")),)),
    new_zealand=(title="New Zealand", query=(:SuperArchipelago=>ByRow(==("New Zealand")),)),
    st_helena=(title="St Helena", query=(:SuperArchipelago=>ByRow(==("St Helena")),)),
    west_indies=(title="West Indies", query=(:SuperArchipelago=>ByRow(==("West Indies")),)),
    hawaiian_islands=(title="Hawaiian Islands", query=(:Archipelago=>ByRow(==("Hawaiian Islands")),)),
    polynesia=(title="Polynesia", query=(:SuperArchipelago=>ByRow(==("Polynesia")),)),
    micronesia=(title="Micronesia", query=(:SuperArchipelago=>ByRow(==("Micronesia")),)),
    galapagos=(title="Galapagos", query=(:Archipelago=>ByRow(==("Galapagos")),)),
)

s1.classNum = collect(map(x -> findfirst(==(x), intersect(classes, s1.className)) , s1.className))
s2 = s1
# s2 = subset(s1, :className => ByRow(==("AVES")))
# s2 = subset(s1, :className => ByRow(==("REPTILIA")))
# s2 = subset(s1, :className => ByRow(==("MAMMALIA")))
# s2 = subset(s1, :yearLastSeen_cleaned => ByRow(>=(1750)))
# s2 = subset(s1, :yearLastSeen_cleaned => ByRow(<(1750)))
subsets = map(subset_queries) do qs
    df = subset(s2, qs.query...; skipmissing=true)
    merge(qs, (; df))
end
trends = map(subsets) do (; df)
    xs, ys = df.yearLastSeen_cleaned, log.(df.EstimatedMass)
    classify_trend(xs, ys)
end



# Plotting

subset_layout = [
    :islands             :islands_early     :islands_late #nothing
    :inhabited_islands   :inhabited_early   :inhabited_late #:west_indies
    :uninhabited_islands :uninhabited_early :uninhabited_late #nothing
]
using CairoMakie
fig = plot_subsets(subset_layout, subsets, trends; colorrange=(1, 4))
save("images/mass_and_extinction.png", fig)

subset_australia = [:australia :australian_continent :australian_uninhabited_islands]
fig = plot_subsets(subset_australia, subsets, trends; colorrange=(1, 4))
save("images/mass_and_extinction_australia.png", fig)

plot_extinctions(subsets.australian_continent.df)
plot_extinctions(subsets.australian_islands.df)

edges = 10.0 .^ (-1:9)
bins = log.(edges)

density_layout = (
    :islands,
    # :inhabited_islands,
    # :uninhabited_islands,
    # :islands_early,
    # :islands_late,
    :inhabited_early,
    :uninhabited_early,
    :inhabited_late,
    :uninhabited_late,
)
vertebrates = log.(skipmissing(mean_mass_df.Mass_mean))
groups = map(subsets[density_layout]) do (; df)
    log.(df.EstimatedMass)
end
logmasses = merge((; vertebrates), groups)

fig = Figure()
ax = Axis(fig[1, 1])
colors = ColorSchemes.Paired_10
map(logmasses, enumerate(keys(logmasses))) do lm, (i, label)
    println(label)
    density!(ax, lm;
        color=(:white, 0.0),
        label=string(label),
        strokecolor=colors[i],
        strokewidth=2,
    )
end
axislegend(ax; position=:rt)


density(xs)
Makie.hist(xs;
    axis=(;
        xlabel="Mass (g)",
        xticks = (bins, string.(edges)),
        ylabel="Number extinct",
    ),
    # normalization=:pdf,
    bins,
    colormap=:magma,
    color=:values,
    strokecolor=:black,
    strokewidth=1,
    bar_labels=:values,
    label_color=:black,
    label_size=12,
    # label_formatter=x-> round(Int, x),
)

# Test that class masses and mass variance are not different to the total
groups = collect(groupby(s1, :className))
class_masses = (classes .=> map(groups) do group
    EqualVarianceTTest(log.(group.EstimatedMass), log.(s1.EstimatedMass))
end) |> Dict
class_masses["MAMMALIA"]
class_masses["REPTILIA"]
class_masses["AVES"]

class_masses = (classes .=> map(groups) do group
    UnequalVarianceTTest(log.(group.EstimatedMass), log.(s1.EstimatedMass))
end) |> Dict
class_masses["MAMMALIA"]
class_masses["REPTILIA"]
class_masses["AVES"]

class_masses = (classes .=> map(groups) do group
    VarianceFTest(log.(group.EstimatedMass), log.(s1.EstimatedMass))
end) |> Dict
class_masses["MAMMALIA"]
class_masses["REPTILIA"]
class_masses["AVES"]

# save("images/dome_extinction.png", fig)

fig = Figure(; size=(900, 600));
kw = (; yscale=log10, xlabel="Year of last sighting", ylabel="Mass (g)")
ax1 = Axis(fig[1, 1]; kw...)
ax2 = Axis(fig[2, 1]; kw...)
linkaxes!(ax1, ax2)
# fig[0, 1] = Label(fig, "Mass of extinct species in Australia", fontsize=20)
plot_extinctions!(ax1, subs.australian_continent.df; names=true)
plot_extinctions!(ax2, subs.australian_uninhabited_islands.df; names=true)
display(fig)
save("australia_extinction_mass.png", fig)
