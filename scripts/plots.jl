using CSV
using DataFrames
using ColorSchemes
using Colors
using StatsBase
# using CairoMakie
using GLMakie

using GlobalExtinctionPatterns

# Load data and process
basepath = realpath(joinpath(dirname(pathof(GlobalExtinctionPatterns)), ".."))

extinct_species_mass_path = joinpath(basepath, "data/extinct_species_mass.csv")
classes = ["AVES", "MAMMALIA", "REPTILIA"]

# Remove to generate data again from raw sources
# rm(extinct_species_mass_path)

if isfile(extinct_species_mass_path)
    s1 = CSV.read(extinct_species_mass_path, DataFrame)
else
    extinctions_csv_path = "/home/raf/PhD/Mascarenes/MauritiusExtinctions/tables/IUCN_extinctions.csv"
    extinctions_download = "/home/raf/Downloads/IUCN Extinctions - assessments_gbif.csv"
    isfile(extinctions_download) && mv(extinctions_download, extinctions_csv_path; force=true)

    # GBIF data ##################################################################
    
    s = CSV.read(extinctions_csv_path, DataFrame; types=Dict(:LocationColonised=>Int, :ArchipelagoColonised=>Int)) |>
    x -> filter(x) do row
        !ismissing(row.kingdomName) &&
        row.kingdomName == "ANIMALIA" &&
        row.className in classes && # No fish or molluscs 
        row.systems != "Marine" && # No marine species like seals or whales
        true # Lets us comment out any line above without breaking things
    end
    set_gbif_species!(s, :scientificName)

    # Trait data ###################################################################33

    # List all trait csvs, with mass and binomial name column names
    trait_csvs = (;
        atb_anura=(csv="/home/raf/Data/Traits/AmphibianTraitsDatabase/Anura.csv", mass=:SVL, binomial=:Species),
        atb_caudata=(csv="/home/raf/Data/Traits/AmphibianTraitsDatabase/Caudata.csv", mass=:SVL, binomial=:Species),
        atb_gymnophiona=(csv="/home/raf/Data/Traits/AmphibianTraitsDatabase/Gymnophiona.csv", mass=:SVL, binomial=:Species),
        hawaii=(csv="/home/raf/PhD/Mascarenes/MauritiusExtinctions/tables/FE.Case.Tarwater_2020.csv", mass=Symbol("Body.mass_grams"), binomial=:Species),
        mascarene=(csv="../MauritiusExtinctions/tables/mascarene_species.csv", mass=:Mass, binomial=:Species),
        pantheria=(csv="/home/raf/Data/Traits/PanTHERIA/ECOL_90_184/PanTHERIA_1-0_WR05_Aug2008_gbif.csv", mass=:AdultBodyMass_g, binomial=:MSW05_Binomial),
        avonet = (csv="/home/raf/Data/Traits/Avonet/ELEData/ELEData/TraitData/AVONET1_BirdLife_gbif.csv", mass=:Mass, binomial=:Species1),
        # lizzard = (csv="/home/raf/Data/Traits/Lizards/Appendix S1 - Lizard data version 1.0.csv" binomial=:XX),
        elton_mammal = (csv="/home/raf/Data/Traits/EltonTraits/MamFuncDat_gbif.csv", mass=:BodyMass_Value, binomial=:Scientific),
        elton_bird = (csv="/home/raf/Data/Traits/EltonTraits/BirdFuncDat_gbif.txt", mass=:BodyMass_Value, binomial=:Scientific),
        reptile_mass = (csv="/home/raf/PhD/Mascarenes/Tables/Reptile body mass database Meiri 2010_gbif.csv", mass=Symbol("Weight (g)"), binomial=:Name),
        # bird_mass = (csv="/home/raf/PhD/Mascarenes/Tables/Bird Mass filled (Jan 22 2015)_WDK_gbif.csv", mass=:filledmass, binomial=:BirdLife_SpecName),
        frugivores = (csv="../MauritiusExtinctions/tables/Dryad frugivore occurrence database 1-3-17.csv", mass=:Body_mass, binomial=:Species_name),
    )

    (; s1, mean_mass_df) = load_mass_traits(s, trait_csvs;
        weigelt_csv = "/home/raf/Data/Extinction/Islands/Weigelt/Weigelt_etal_2013_PNAS_islanddata.csv",
        heinen_csv = "/home/raf/PhD/Mascarenes/MauritiusExtinctions/tables/Heinen_extinct_terrestrial_vertebrates.csv",
    )

    CSV.write(extinct_species_mass_path, s1)
end

# Add numerical classes for plot colors 
s1.classNum = collect(map(x -> findfirst(==(x), intersect(classes, s1.className)) , s1.className))

# Inspect the data
sort(s1.Location |> countmap |> pairs |> collect; by=last)
sort(s1.Archipelago |> countmap |> pairs |> collect; by=last)
sort(s1.SuperArchipelago |> countmap |> pairs |> collect; by=last)
sort(collect(s1.Archipelago |> countmap); by=last)


# Subsetting #################################################################3

not_mauris = :GBIFSpecies => ByRow(!in(("Chenonetta finschi", "Tribonyx hodgenorum")))
subset_queries = (;
    all=(title="All colonised", query=()),
    birds=(title="All colonised", query=(:className => ByRow(==("AVES")),)),
    mammals=(title="All colonised", query=(:className => ByRow(==("MAMMALIA")),)),
    reptiles=(title="All colonised", query=(:className => ByRow(==("REPTILIA")),)),
    islands=(title="All Islands", query=(:isisland,)),
    continents=(title="Continents", query=(:isisland => .!,)),
    inhabited_islands=(title="Inhabited", query=(:isisland, :wasuninhabited => .!,)),
    uninhabited_islands=(title="Uninhabited", query=(:isisland, :wasuninhabited,)),
    indian_ocean=(title="Indian ocean", query=(:SuperArchipelago=>ByRow(==("Indian Ocean")),)),
    mascarenes=(title="Mascarenes", query=(:Archipelago=>ByRow(==("Mascarenes")),)),
    not_mascarenes=(title="Not Mascarenes", query=(:Archipelago=>ByRow(!=("Mascarenes")),)),
    non_mascarene_uninhabited=(title="Non-Mascarene Uninhabited", query=(:isisland, :wasuninhabited, :Archipelago=>ByRow(!=("Mascarenes")),)),
    islands_early=(title="All Early Colonisation", query=(:isisland, :colonised=>ByRow(<(1750)),)),
    islands_late=(title="All Late Colonisation", query=(not_mauris, :isisland, :colonised=>ByRow(>=(1750)),)),
    inhabited_early=(title="Inhabited Early Colonisation", query=(:isisland, :wasuninhabited => .!, :colonised=>ByRow(<(1750)),)),
    inhabited_late=(title="Inhabited Late Colonisation", query=(not_mauris, :isisland, :wasuninhabited => .!, :colonised=>ByRow(>=(1750)),)),
    uninhabited_early=(title="Uninhabited Early Colonisation", query=(:isisland, :wasuninhabited, :colonised=>ByRow(<(1750)),)),
    uninhabited_late=(title="Uninhabited Late Colonisation", query=(not_mauris, :isisland, :wasuninhabited, :colonised=>ByRow(>=(1750)),)),

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

subsets = map(subset_queries) do qs
    df = subset(s1, qs.query...; skipmissing=true)
    merge(qs, (; df))
end

trends = map(subsets) do (; df)
    xs, ys = df.yearLastSeen_cleaned, log.(df.EstimatedMass)
    classify_trend(xs, ys)
end


# Mass vs Extinction time plots ####################################################################3

subset_layout = [
    :islands             :islands_early     :islands_late #nothing
    # :mascarenes          :not_mascarenes    :non_mascarene_uninhabited
    :inhabited_islands   :inhabited_early   :inhabited_late #:west_indies
    :uninhabited_islands :uninhabited_early :uninhabited_late #nothing
]
fig = plot_subsets(subset_layout, subsets, trends; colordata=:colonised)
save("$basepath/images/mass_and_extinction.png", fig)

# Australia

# subset_australia = [:australia :australian_continent :australian_uninhabited_islands]
# fig = plot_subsets(subset_australia, subsets, trends; colorrange=(1, 4))
# save("images/mass_and_extinction_australia.png", fig)


# Individual subset plots

# plot_extinctions(subsets.australian_continent.df)
# plot_extinctions(subsets.australian_islands.df)


# Mass density plots #######################################################

density_layout = (
    # :islands,
    :birds,
    :mammals,
    :reptiles,
    # :inhabited_islands,
    # :uninhabited_islands,
    # :islands_early,
    # :islands_late,
    # :inhabited_early,
    # :uninhabited_early,
    # :inhabited_late,
    # :uninhabited_late,
)
selected_logmasses = map(subsets[density_layout]) do (; df)
    log.(df.EstimatedMass)
end
colors = collect(ColorSchemes.Bay)

# If we have all the animal trait data put it in the plot too
if isdefined(Main, :mean_mass_df)
    colors[1] = RGB(0.0, 0.0, 0.0)
    all_vertebrates = log.(skipmissing(mean_mass_df.Mass_mean))
    all_logmasses = merge((; all_vertebrates), selected_logmasses)
else
    # Otherwise just plot the extinct species
    all_logmasses = selected_logmasses
end

fig = Figure()
ax = Axis(fig[1, 1]; 
    xlabel="Mass",
    xticks = (log.(10 .^ (0:6)), ["1g", "10g", "100g", "1Kg", "10Kg", "100Kg", "1Mg"])
)
xlims!(ax, (0, log(1e6)))
map(all_logmasses, enumerate(keys(all_logmasses))) do lm, (i, label)
    density!(ax, lm;
        boundary=(0, 30),
        color=(:white, 0.0),
        label=titlecase(replace(string(label), "_" => " ")),
        strokecolor=colors[i],
        strokewidth=2,
    )
end
axislegend(ax; position=:rt)

save("$basepath/images/mass_density.png", fig)
