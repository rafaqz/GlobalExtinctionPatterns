
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

INVASIVE_CAUSED = ["8.1.1", "8.1.2", "8.2.1", "8.2.2", "8.4.1", "8.4.2"]
HUMAN_CAUSED = ["5.1.1", "5.1.3", "5.1.4"]
LCC_CAUSED = [
    "1.1",
    "1.2",
    "1.3",
    "2.1.1", "2.1.2", "2.1.3", "2.1.4",
    "2.2.1", "2.2.2", "2.2.3",
    "2.3.1", "2.3.2", "2.3.3", "2.3.4",
    "2.4.1", "2.4.2", "2.4.3",
    "3.1",
    "3.2",
    "3.3",
    "4.1",
    "4.2",
    "4.3",
    "4.4",
    "5.3.1", "5.3.2", "5.3.3", "5.3.4", "5.3.5",
    "6.1",
    "6.2",
    "6.3",
    "7.1.1", "7.1.2", "7.1.3",
    "7.2.1", "7.2.2", "7.2.3", "7.2.4", "7.2.5", "7.2.6", "7.2.7", "7.2.8", "7.2.9", "7.2.10", "7.2.11",
    "7.3",
]
OTHER_CAUSED = [
    "5.1.2",
    "5.2.1", "5.2.2", "5.2.3", "5.2.4",
    "5.4.1", "5.4.2", "5.4.3", "5.4.4", "5.4.5", "5.4.6",
    "8.5.1", "8.5.2", "8.6",
    "9.1.1", "9.1.2", "9.1.3",
    "9.2.1", "9.2.2", "9.2.3",
    "9.3.1", "9.3.2", "9.3.3", "9.3.4",
    "9.4",
    "9.5.1", "9.5.2", "9.5.3", "9.5.4",
    "9.6.1", "9.6.2", "9.6.3", "9.6.4",
    "10.1",
    "10.2",
    "10.3",
    "11.1",
    "11.2",
    "11.3",
    "11.4",
    "11.5",
    "12.1",
]

function add_threat_categories(df)
    df.human_thre = subset(df, :threat_codes => ByRow(x -> any(c -> c in x, HUMAN_CAUSED)))
    df.invasive_thre = subset(df, :threat_codes => ByRow(x -> any(c -> c in x, INVASIVE_CAUSED)))
    df.lcc_thre = subset(df, :threat_codes => ByRow(x -> any(c -> c in x, LCC_CAUSED)))
    df.other_thre = subset(df, :threat_codes => ByRow(x -> any(c -> c in x, OTHER_CAUSED)))
end

function get_subsets(full_df;
    classes = ["AVES", "MAMMALIA", "REPTILIA"],
    not_mauris = :GBIFSpecies => ByRow(!in(("Chenonetta finschi", "Tribonyx hodgenorum"))),
    human_caused = :threat_codes => ByRow(x -> any(c -> c in x, HUMAN_CAUSED)),
    invasive_caused = :threat_codes => ByRow(x -> any(c -> c in x, INVASIVE_CAUSED)),
    lcc_caused = :threat_codes => ByRow(x -> any(c -> c in x, LCC_CAUSED)),
    other_caused = :threat_codes => ByRow(x -> any(c -> c in x, OTHER_CAUSED)),
    subset_queries = (;
        invasive_caused=(title="Invasive caused", query=(invasive_caused,)),
        human_caused=(title="Human hunting caused", query=(human_caused,)),
        lcc_caused=(title="Land cover change caused", query=(lcc_caused,)),
        other_caused=(title="Other caused", query=(other_caused,)),
        invasive_caused_islands=(title="Invasive caused islands", query=(:isisland, invasive_caused,)),
        human_caused_islands=(title="Human hunting caused islands", query=(:isisland, human_caused,)),
        lcc_caused_islands=(title="Land cover change caused islands", query=(:isisland, lcc_caused,)),
        other_caused_islands=(title="Other caused islands", query=(:isisland, other_caused,)),
        invasive_caused_uninhabited=(title="Invasive caused uninhabited", query=(:isisland, :wasuninhabited, invasive_caused,)),
        human_caused_uninhabited=(title="Human hunting caused uninhabited", query=(:isisland, :wasuninhabited, human_caused,)),
        lcc_caused_uninhabited=(title="Land cover change caused uninhabited", query=(:isisland, :wasuninhabited, lcc_caused,)),
        other_caused_uninhabited=(title="Other caused uninhabited", query=(:isisland, :wasuninhabited, other_caused,)),
        invasive_caused_inhabited=(title="Invasive caused inhabited", query=(:isisland, :wasuninhabited => .!, invasive_caused,)),
        human_caused_inhabited=(title="Human hunting caused inhabited", query=(:isisland, :wasuninhabited => .!, human_caused,)),
        lcc_caused_inhabited=(title="Land cover change caused inhabited", query=(:isisland, :wasuninhabited => .!, lcc_caused,)),
        other_caused_inhabited=(title="Other caused inhabited", query=(:isisland, :wasuninhabited => .!, other_caused,)),
        all=(title="", query=()),
        birds=(title="Birds", query=(:className => ByRow(==("AVES")),)),
        mammals=(title="Mammals", query=(:className => ByRow(==("MAMMALIA")),)),
        reptiles=(title="Reptiles", query=(:className => ByRow(==("REPTILIA")),)),
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
)
    map(subset_queries) do qs
        df = subset(full_df, qs.query...; skipmissing=true)
        merge(qs, (; df))
    end
end
