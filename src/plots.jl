function plot_extinctions(df; size=(1000, 1000), kw...)
    fig = Figure(; size)
    ax = plot_extinctions!(fig, df; kw...)
    return fig, ax
    
end
function plot_extinctions!(fig::Figure, df; size=nothing, kw...)
    ax = Axis(fig[1, 1];
        yscale=log10,
        xlabel="Year last seen",
        ylabel="Mass",
    )
    plot_extinctions!(ax, df; kw...)
    return ax
end

function plot_extinctions!(ax::Axis, df;
    title="",        
    colonised=nothing,
    names=nothing,
    colordata=:colonised,
    colormap=:viridis,
    colorrange=(1500, 1900),
    xlims=(1480, 2020),
    ylims=(1.0, 1e6),
    trend=nothing,
    classes = ["AVES", "MAMMALIA", "REPTILIA"],
)
    xlims!(ax, xlims)
    ylims!(ax, ylims)
    for class in classes
        df_c = subset(df, :className => ByRow(==(class)))
        xs, ys = df_c.yearLastSeen_cleaned, df_c.EstimatedMass
        # xs, ys = s1.yearLastSeen_cleaned .- s1.colonised, log.(s1.Mass)
        # ys = shuffle(ys)
        color = colordata isa Symbol ? getproperty(df_c, colordata) : colordata
        Makie.plot!(ax, xs, ys;
            # color,
            label=class,
            # colormap, colorrange,
            inspector_label=(_, i, _) -> "$(df_c.GBIFSpecies[i])\nClass: $(df_c.className[i])\nIsland: $(df_c.Location[i])\nArea: $(df_c.Area[i])\nMass: $(ys[i])\nExtinct: $(xs[i])",
        )
    end
    if names == :text
        Makie.text!(ax, xs, ys; text=df.GBIFSpecies)
    end
    # p = Makie.plot!(ax, longlived.yearLastSeen_cleaned, longlived.EstimatedMass; color=(:yellow, 0.5), label="Long lived")#; color=df.colonised, colormap=:viridis)

    xs, ys = df.yearLastSeen_cleaned, df.EstimatedMass
    Makie.hlines!(ax, exp.(mean(log.(ys))); color=:black, label="Median mass")
    if !isnothing(colonised)
        Makie.vlines!(ax, df.colonised; color=colonised, label="Colonisation")
    end
    if isnothing(trend) # Do a loess regression
        model = loess(xs, log.(ys), span=1.0, degree=2)
        us = range(extrema(xs)...; step=5)
        vs = exp.(predict(model, us))
        Makie.lines!(ax, us, vs; label="Loess regression", color=(:black, 0.8))
    elseif !ismissing(trend.model) && trend.r2 != -Inf # Use the trend curve
        minx, maxx = extrema(xs)
        trend_predictions = predict(trend.model, (; x=0:maxx-minx); interval=:confidence, level=0.95)
        ax.title = "$title: $(trend.class)"
        # Fix the log scale
        Makie.lines!(ax, minx:maxx, exp.(trend_predictions.prediction), label="Trend")
        # Makie.band!(ax, minx:maxx, exp.(trend_predictions.lower), exp.(trend_predictions.upper);
        #     color=(:grey, 0.1),
        # )
    end

    DataInspector(ax)
end

function plot_subsets(subset_layout, subsets, trends;
    colormap=:managua,
    colordata=:colonised,
    colorrange=extrema(skipmissing(getproperty(subsets.all.df, colordata))),
    size=(1600, 900),
)
    kw = (; yscale=log10, xlabel="Year last seen", ylabel="Mass")
    fig = Figure(; size);
    key = :uninhabited_early
    I = 1, 1
    axs = map(subset_layout, CartesianIndices(subset_layout)) do key, I
        if isnothing(key)
            ax = Axis(fig[Tuple(I)...])
            xlims!(ax, (1400, 2020))
            ylims!(ax, (1.0, 1e6))
        else
            sub = subsets[key]
            trend = trends[key]
            ax = Axis(fig[Tuple(I)...]; title="$(sub.title) : $(trend.class)", kw...)
            I[1] == Base.size(subset_layout, 1) || hidexdecorations!(ax; grid=false)
            I[2] == 1 || hideydecorations!(ax; grid=false)
            plot_extinctions!(ax, sub.df;
                # colonised=(:black, 0.02),
                names=:tooltip,
                colordata, colorrange, colormap,
                trend
            )
        end
        Makie.hidespines!(ax)
        ax
    end
    linkaxes!(axs...)
    # Makie.Colorbar(fig[UnitRange(axes(subset_layout, 1)), size(subset_layout, 2) + 1];
    #     colormap,
    #     colorrange=extrema(getproperty(s1, colordata)),
    #     label="Colonisation date",
    # )
    axislegend(axs[3]; position=:lt)
    fig[0, :] = Label(fig, "Patterns of mass, extinction date, and human habitation", fontsize=20)
    return fig
end
