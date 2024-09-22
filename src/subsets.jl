
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

INVASIVE_CAUSED = findfirst(==("Invasive & diseases"), cause_labels)
HUMAN_CAUSED = findfirst(==("Biological resource use"), cause_labels)
LCC_CAUSED = map(s -> findfirst(==(s), cause_labels), [
    "Residential & commercial"
    "Agriculture & aquaculture"
    "Energy production & mining"
    "Transport corridors"
    "Human disturbance"
    "Natural system modifications"
])

function get_subsets(full_df;
    classes = ["AVES", "MAMMALIA", "REPTILIA"],
    not_mauris = :GBIFSpecies => ByRow(!in(("Chenonetta finschi", "Tribonyx hodgenorum"))),
    subset_queries = (;
        invasive_caused=(title="Invasive caused", query=(:threat_codes => ByRow(t -> INVASIVE_CAUSED in t),)), 
        human_caused=(title="Human resource use caused", query=(:threat_codes => ByRow(t -> HUMAN_CAUSED in t),)), 
        lcc_caused=(title="Land cover change caused", query=(:threat_codes => ByRow(t -> any(c -> c in t, LCC_CAUSED)),)), 
        invasive_caused_islands=(title="Invasive caused islands", query=(:isisland, :threat_codes => ByRow(t -> INVASIVE_CAUSED in t),)), 
        human_caused_islands=(title="Human resource use caused islands", query=(:isisland, :threat_codes => ByRow(t -> HUMAN_CAUSED in t),)), 
        lcc_caused_islands=(title="Land cover change caused islands", query=(:isisland, :threat_codes => ByRow(t -> any(c -> c in t, LCC_CAUSED)),)), 
        invasive_caused_uninhabited=(title="Invasive caused", query=(:isisland, :wasuninhabited, :threat_codes => ByRow(t -> INVASIVE_CAUSED in t),)), 
        human_caused_uninhabited=(title="Human resource use caused", query=(:isisland, :wasuninhabited, :threat_codes => ByRow(t -> HUMAN_CAUSED in t),)), 
        lcc_caused_uninhabited=(title="Land cover change caused", query=(:isisland, :wasuninhabited, :threat_codes => ByRow(t -> any(c -> c in t, LCC_CAUSED)),)), 
        invasive_caused_inhabited=(title="Invasive caused", query=(:isisland, :wasuninhabited => .!, :threat_codes => ByRow(t -> INVASIVE_CAUSED in t),)), 
        human_caused_inhabited=(title="Human resource use caused", query=(:isisland, :wasuninhabited => .!, :threat_codes => ByRow(t -> HUMAN_CAUSED in t),)), 
        lcc_caused_inhabited=(title="Land cover change caused", query=(:isisland, :wasuninhabited => .!, :threat_codes => ByRow(t -> any(c -> c in t, LCC_CAUSED)),)), 
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
)
    map(subset_queries) do qs
        df = subset(full_df, qs.query...; skipmissing=true)
        merge(qs, (; df))
    end
end
