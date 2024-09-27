using Revise
using ColorSchemes
using KernelDensity
using DataFrames
using JSON3
using CairoMakie
using GBIF2
using StatsBase

using GlobalExtinctionPatterns

basepath = GlobalExtinctionPatterns.basepath
datapath = joinpath(basepath, "data")
imagepath = joinpath(basepath, "images")
cause_labels = GlobalExtinctionPatterns.cause_labels

classes = ["AVES", "MAMMALIA", "REPTILIA"]
mass_df = load_mass_table(; classes=nothing)
mass_df.threat_groups = get_threat_groups(mass_df, datapath)
mass_df.threat_codes = get_threat_codes(mass_df, datapath)
subsets = get_subsets(mass_df)

# Order threats for a nice color progression
# We omit "Climate & weather", "Geological events" 
# and "Other options" for simplicity
b = findfirst(==("Biological resource use"), cause_labels) 
i = findfirst(==("Invasive & diseases"), cause_labels) 
a = findfirst(==("Agriculture & aquaculture"), cause_labels) 
r = findfirst(==("Residential & commercial"), cause_labels) 
n = findfirst(==("Natural system modifications"), cause_labels) 
d = findfirst(==("Human disturbance"), cause_labels) 
e = findfirst(==("Energy production & mining"), cause_labels) 
t = findfirst(==("Transport corridors"), cause_labels) 
p = findfirst(==("Pollution"), cause_labels) 
selected_threats = [i, b, a, r, t, n, d, e, p]

function plot_threat_density!(ax, df, selected_threats; 
    normalise=false
)
    threat_groups = map(1:12) do threat_code
        subset(df, 
            :className => ByRow(in(classes)), 
            :threat_groups => ByRow(tcs -> threat_code in tcs),
        )
    end
    colors = ColorSchemes.Bay
    labels = cause_labels[selected_threats]
    groups = threat_groups[selected_threats]
    # selected_threats = eachindex(cause_labels)
    upper = nothing
    # k = cause_labels[a]
    # group = threat_groups[a]
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
        if normalise
            (; 
                lower=lower ./ last(group_stats).upper,
                upper=upper ./ last(group_stats).upper,
                kde,
            )
        else
            (; 
                lower=lower,
                upper=upper,
                kde,
            )
        end
    end
    length(group_stats)
    i = 2
    for i in reverse(eachindex(groups))
        s = group_stats[i]
        @show i s.kde.x
        Makie.band!(ax, s.kde.x, s.lower, s.upper;
            label=string(labels[i]), 
            # color=(:white, 0.0),
            color=(get(colors, i/length(groups)), 0.95),
            # strokecolor=get(colors, i/length(selected_threats)), p2_kw...
        )
    end
    if !normalise
        axislegend(ax; position=(0.1, normalise ? 0.1 : 0.9), framevisible=false)
    end
    hidedecorations!(ax; label=false, ticks=false, ticklabels=false)
    hidespines!(ax)
    xlims!(ax, (1500, 2024))
    return fig, ax
end

sub = :mascarenes
sub = :birds
sub = :all
normalise = false
fig = Figure(; size=(1000, 400));
ax_kw = (; xlabel="Year", xticks=1500:100:2000)
ax1 = Axis(fig[1, 1];
    ylabel="Cause density (multiple per individual possible)",
    ax_kw...
)
ax2 = Axis(fig[1, 2];
    ylabel="Cause fraction (multiple per individual possible)",
    ax_kw...
)
df = subsets[sub].df
plot_threat_density!(ax1, subsets[sub].df, selected_threats; normalise=false)
plot_threat_density!(ax2, subsets[sub].df, selected_threats; normalise=true)
fig
save(joinpath(imagepath, "historical_extinction_causes.png"), fig)
