
function load_mass_table(path=joinpath(basepath, "data/extinct_species_mass.csv");
    classes=["AVES", "MAMMALIA", "REPTILIA"],
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
    ),
    weigelt_csv = "/home/raf/Data/Extinction/Islands/Weigelt/Weigelt_etal_2013_PNAS_islanddata.csv",
    heinen_csv = "/home/raf/PhD/Mascarenes/MauritiusExtinctions/tables/Heinen_extinct_terrestrial_vertebrates.csv",
)
    @show classes
    if isfile(path)
        s1 = CSV.read(path, DataFrame)
    else
        extinctions_csv_path = "/home/raf/PhD/Mascarenes/MauritiusExtinctions/tables/IUCN_extinctions.csv"
        extinctions_download = "/home/raf/Downloads/IUCN Extinctions - assessments_gbif.csv"
        isfile(extinctions_download) && mv(extinctions_download, extinctions_csv_path; force=true)

        # GBIF data ##################################################################
        
        s = CSV.read(extinctions_csv_path, DataFrame; types=Dict(:LocationColonised=>Int, :ArchipelagoColonised=>Int)) |>
        x -> filter(x) do row
            !ismissing(row.kingdomName) &&
            row.kingdomName == "ANIMALIA" &&
            (isnothing(classes) || row.className in classes) && # No fish or molluscs 
            row.systems != "Marine" && # No marine species like seals or whales
            true # Lets us comment out any line above without breaking things
        end
        set_gbif_species!(s, :scientificName)

        # Trait data ###################################################################33

        # List all trait csvs, with mass and binomial name column names
        (; s1, mean_mass_df) = load_mass_traits(s, trait_csvs; weigelt_csv, heinen_csv,)

        CSV.write(path, s1)
    end
end
