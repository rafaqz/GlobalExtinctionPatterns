using Revise
using Colors
using ColorSchemes
using KernelDensity
using DataFrames
using JSON3
using CairoMakie
using GBIF2
using StatsBase

using GlobalExtinctionPatterns
const GEP = GlobalExtinctionPatterns

basepath = GlobalExtinctionPatterns.basepath
datapath = joinpath(basepath, "data")
imagepath = joinpath(basepath, "images")
cause_labels = GlobalExtinctionPatterns.cause_labels

classes = ["AVES", "MAMMALIA", "REPTILIA"]
mass_df = load_mass_table(; classes=nothing)
mass_df.threat_groups = get_threat_groups(mass_df, datapath)
mass_df.threat_codes = get_threat_codes(mass_df, datapath)
subsets = get_subsets(mass_df)

function GEP.plot_threat_density!(ax, df; classes, colors)
    threat_groups = map(1:12) do threat_code
        subset(df,
            :className => ByRow(in(classes)),
            :threat_groups => ByRow(tcs -> threat_code in tcs),
        )
    end
    labels = ["Invasives", "Hunting", "Land cover", "Other",]
    group_queries = (
        :threat_codes => ByRow(x -> any(c -> c in x, GEP.INVASIVE_CAUSED)),
        :threat_codes => ByRow(x -> any(c -> c in x, GEP.HUMAN_CAUSED)),
        :threat_codes => ByRow(x -> any(c -> c in x, GEP.LCC_CAUSED)),
        :threat_codes => ByRow(x -> any(c -> c in x, GEP.OTHER_CAUSED)),
    )
    groups = map(group_queries) do q
        subset(df, q)
    end
    upper = nothing
    all_years = collect(skipmissing(df.yearLastSeen_cleaned))
    kde_kw = (; boundary=(1350, 2025), npoints=2025-1350+1, bandwidth=25)
    u_all = kde(all_years; kde_kw...)
    group_stats = map(groups) do group
        years = collect(skipmissing(group.yearLastSeen_cleaned))
        u = kde(years; kde_kw...)
        adjusted_density = u.density .* length(years)
        if isnothing(upper)
            upper = adjusted_density
            lower = adjusted_density .* 0
        else
            lower = upper
            upper = upper .+ adjusted_density
        end
        (; lower, upper, kde=u)
    end
    group_stats = map(group_stats) do (; lower, upper, kde)
        (;
            lower=lower ./ last(group_stats).upper .- 0.001,
            upper=upper ./ last(group_stats).upper,
            kde,
        )
    end
    length(group_stats)
    i = 2
    for i in reverse(eachindex(groups))
        s = group_stats[i]
        Makie.band!(ax, s.kde.x, s.lower, s.upper;
            label=string(labels[i]),
            color=colors[i],
        )
    end
    for i in reverse(eachindex(groups))
        s = group_stats[i]
        Makie.lines!(ax, s.kde.x, s.upper;
            color=:black,
            linewidth=2,
        )
    end
    vlines!(ax, all_years;
         color=(:black, 0.30),
         linewidth=2,
         ymin=-0.1,
         ymax=0.06,
    )
    return ax
end

# Add numerical classes for plot colors
mass_df.classNum = collect(map(x -> findfirst(==(x), intersect(classes, mass_df.className)) , mass_df.className))
subsets = get_subsets(mass_df)
trends = map(subsets) do (; df)
    xs, ys = df.yearLastSeen_cleaned, log.(df.EstimatedMass)
    classify_trend(xs, ys)
end

cause_colors = map(i -> get(ColorSchemes.island, i/5), 1:4)
cause_layout = [
    :invasive_caused :human_caused :lcc_caused
]

fig = let
    fig = plot_subsets(cause_layout, subsets, trends;
        size=(900, 580),
        legend=(axisnum=1, position=:lt),
    )
    map(0:1, ["A", "B"]) do row, text
        ax = Axis(fig[row, 0])
        hidedecorations!(ax)
        hidespines!(ax)
        xlims!(ax, (0, 1))
        ylims!(ax, (0, 1))
        text!(ax, 0.0, 0.9; text, fontsize=20, font="Arial bold")
    end
    colsize!(fig.layout, 0, Relative(0.02))
    ax = Axis(fig[0, 1:3];
        # xlabel="Year last seen",
        ylabel="Fraction of causes",
        spinewidth=2,
        xticks=1500:100:2000, 
        yticks=0.0:0.2:1.0,
    )
    hidedecorations!(ax; label=false, ticks=false, ticklabels=false)
    xlims!(ax, (1500, 2024))
    ylims!(ax, (-0.06, 1.0))
    df = subsets[sub].df
    plot_threat_density!(ax, subsets[sub].df; classes, colors=cause_colors)
    Legend(fig[0, 4], ax; 
        position=(0.0, 0.13), 
        framevisible=false,
        patchstrokewidth=3,
        patchstrokecolor=:black,
        rowgap=5,
    )
    hlines!(ax, 0.0; 
        color=:black,
        linewidth=2,
    )
    colgap!(fig.layout, 1, 0)
    fig
end

save(joinpath(imagepath, "historical_extinction_causes.png"), fig)

group_queries = (
    :threat_codes => ByRow(x -> any(c -> c in x, GEP.OTHER_CAUSED)),
    :threat_codes => ByRow(x -> any(c -> c in x, GEP.HUMAN_CAUSED)),
    :threat_codes => ByRow(x -> any(c -> c in x, GEP.INVASIVE_CAUSED)),
    :threat_codes => ByRow(x -> any(c -> c in x, GEP.LCC_CAUSED)),
)
groups = map(group_queries) do q
    subset(subsets[:all].df, q)
end
groups[1].threat_codes
filter(r -> !("8.1.2" in r.threat_codes), groups[1]).threat_codes
