function get_subsets(full_df;
    classes = ["AVES", "MAMMALIA", "REPTILIA"],
    not_mauris = :GBIFSpecies => ByRow(!in(("Chenonetta finschi", "Tribonyx hodgenorum"))),
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
)
    map(subset_queries) do qs
        df = subset(full_df, qs.query...; skipmissing=true)
        merge(qs, (; df))
    end
end
