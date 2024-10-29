
function load_mass_table(path=joinpath(basepath, "data/extinct_species_mass.csv");
    classes=["AVES", "MAMMALIA", "REPTILIA"],
    traits_path="/home/raf/Data/Traits",
    # All traits datasets used for masses
    trait_csvs = (;
        atb_anura=(csv=joinpath(traitspath, "AmphibianTraitsDatabase/Anura.csv"), mass=:SVL, binomial=:Species),
        atb_caudata=(csv=joinpath(traitspath, "AmphibianTraitsDatabase/Caudata.csv"), mass=:SVL, binomial=:Species),
        atb_gymnophiona=(csv=joinpath(traitspath, "AmphibianTraitsDatabase/Gymnophiona.csv"), mass=:SVL, binomial=:Species),
        hawaii=(csv=joinpath(traitspath, "FE.Case.Tarwater_2020.csv"), mass=Symbol("Body.mass_grams"), binomial=:Species),
        pantheria=(csv=joinpath(traitspath, "PanTHERIA/ECOL_90_184/PanTHERIA_1-0_WR05_Aug2008_gbif.csv"), mass=:AdultBodyMass_g, binomial=:MSW05_Binomial),
        avonet = (csv=joinpath(traitspath, "Avonet/ELEData/ELEData/TraitData/AVONET1_BirdLife_gbif.csv"), mass=:Mass, binomial=:Species1),
        elton_mammal = (csv=joinpath(traitspath, "EltonTraits/MamFuncDat_gbif.csv"), mass=:BodyMass_Value, binomial=:Scientific),
        elton_bird = (csv=joinpath(traitspath, "EltonTraits/BirdFuncDat_gbif.txt"), mass=:BodyMass_Value, binomial=:Scientific),
        reptile_mass = (csv=joinpath(traitspath, "Reptile body mass database Meiri 2010_gbif.csv"), mass=Symbol("Weight (g)"), binomial=:Name),
        frugivores = (csv=joinpath(traitspath, "Dryad frugivore occurrence database 1-3-17.csv"), mass=:Body_mass, binomial=:Species_name),
        # mascarene=(csv=joinpath(traitspath, "mascarene_species.csv", mass=:Mass, binomial=:Species),
        # lizzard = (csv="/home/raf/Data/Traits/Lizards/Appendix S1 - Lizard data version 1.0.csv" binomial=:XX),
        # bird_mass = (csv="/home/raf/PhD/Mascarenes/Tables/Bird Mass filled (Jan 22 2015)_WDK_gbif.csv", mass=:filledmass, binomial=:BirdLife_SpecName),
    ),
    weigelt_csv = "/home/raf/Data/Extinction/Islands/Weigelt/Weigelt_etal_2013_PNAS_islanddata.csv",
    extinctions_csv_path=joinpath(basepath, "data/IUCN_extinctions.csv")
)
    # Here we avoid time-consuming compilation of data and claissification 
    # against the GBIF backbone by simply loading the completed file.
    if !isfile(path)
        # Load IUCN data ##################################################################
        df = CSV.read(extinctions_csv_path, DataFrame; 
            # Force these not to be strings or floating point
            types=Dict(:LocationColonised=>Int, :ArchipelagoColonised=>Int)
        ) |> x -> filter(x) do row
            !ismissing(row.kingdomName) && 
            row.kingdomName == "ANIMALIA" && # Make sure we have animals if there are no classes
            (isnothing(classes) || row.className in classes) && # No fish or molluscs 
            row.systems != "Marine" && # No marine species like seals or whales
            true # Lets us comment out any line above without breaking things
        end

        # Add a GBIFSpecies column using the GBIF API species match
        set_gbif_species!(df, :scientificName)

        # Trait data ###################################################################33

        # List all trait csvs, with mass and binomial name column names
        (; df_mass, mean_mass_df) = load_mass_traits(df, trait_csvs; weigelt_csv)

        # Write to a file
        CSV.write(path, df_mass)
    end

    return CSV.read(path, DataFrame)
end
