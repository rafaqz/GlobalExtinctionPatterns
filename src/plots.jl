function plot_extinctions(x::NamedTuple; 
    trend=nothing,
    kw...
)
    plot_extinctions(x.df; 
        title="$(x.title)" * (isnothing(trend) ? "" : " : $(trend.class)"), 
        trend,
        kw...
    )
end
function plot_extinctions(df; size=(1000, 1000), kw...)
    fig = Figure(; size, fonts=(; regular = "arial"))
    ax = plot_extinctions!(fig, df; kw...)
    return fig, ax
end

function plot_extinctions!(fig::Figure, df; 
    size=nothing,
    title="",
    xlabel="Year last seen",
    ylabel="Mass (g)",
    classes=["AVES", "MAMMALIA", "REPTILIA"],
    colordata=:colonised,
    colormap=:Egypt,
    colorrange=(1, 4),
    density=false,
    kw...
)
    ax = Axis(fig[1, 1];
        yscale=log10,
        spinewidth=2,
        title, 
        xlabel, 
        ylabel,
        xticks=XTICKS, 
        xgridwidth=2, ygridwidth=2, 
    )
    plot_extinctions!(ax, df; classes, colormap, colordata, colorrange, kw...)
    if density
        ax0 = Axis(fig[0, 1];
            spinewidth=0,
        )
        ax2 = Axis(fig[1, 2];
            # yscale=log10,
            spinewidth=0,
        )
        xlims!(ax0, 1470, 2030)
        ylims!(ax2, 0, log10(1e6))
        linkxaxes!(ax, ax0)
        # linkyaxes!(ax, ax2)
        hidedecorations!(ax0)
        hidedecorations!(ax2)
        rowsize!(fig.layout, 0, Relative(0.05))
        colsize!(fig.layout, 2, Relative(0.05))
        rowgap!(fig.layout, 1, 0)
        colgap!(fig.layout, 1, 0)
        for (c, class) in enumerate(classes)
            df_c = subset(df, :className => ByRow(==(class)))
            xs, ys = df_c.yearLastSeen_cleaned, df_c.EstimatedMass
            color = colordata isa Symbol ? getproperty(df_c, colordata) : colordata

            # For interactive inspection
            Makie.density!(ax0, xs;
                direction=:x,
                boundary=(1440, 2030),
                bandwidth=20,
                color=(to_colormap(colormap)[c], 0.7),
            )
            # For interactive inspection
            Makie.density!(ax2, log10.(ys);
                direction=:y,
                boundary=(0, log10(1e7)),
                bandwidth=0.2,
                color=(to_colormap(colormap)[c], 0.7),
            )
        end
    end

    return ax
end

function plot_extinctions!(ax::Axis, df;
    title="",        
    colonised=nothing,
    names=nothing,
    colormap=:Egypt,
    colordata=:colonised,
    colorrange=(1, 4),
    xlims=(1480, 2020),
    ylims=(1.0, 1e6),
    trend=nothing,
    classes = ["AVES", "MAMMALIA", "REPTILIA"],
    legend=true,
    density=false,
    kw...
)
    xlims!(ax, xlims)
    ylims!(ax, ylims)
    for (c, class) in enumerate(classes)
        df_c = subset(df, :className => ByRow(==(class)))
        xs, ys = df_c.yearLastSeen_cleaned, df_c.EstimatedMass
        # xs, ys = s1.yearLastSeen_cleaned .- s1.colonised, log.(s1.Mass)
        color = colordata isa Symbol ? getproperty(df_c, colordata) : colordata
        # For interactive inspection
        Makie.scatter!(ax, xs, ys;
            color=c,
            colormap,
            colorrange,
            label=titlecase(class),
            alpha=0.9,
            inspector_label=(_, i, _) -> "$(df_c.GBIFSpecies[i])\nClass: $(df_c.className[i])\nIsland: $(df_c.Location[i])\nArea: $(df_c.Area[i])\nMass: $(ys[i])\nExtinct: $(xs[i])",
        )
    end

    xs = df.yearLastSeen_cleaned
    if !isnothing(colonised)
        Makie.vlines!(ax, df.colonised; linewidth=2, color=colonised, label="Colonisation")
    end
    if isnothing(trend) # Do a loess regression
        model = loess(xs, log.(df.EstimatedMass), span=1.0, degree=2)
        us = range(extrema(xs)...; step=5)
        vs = exp.(predict(model, us))
        Makie.lines!(ax, us, vs; linewidth=2, label="Loess regression", color=(:black, 0.8))
    elseif !ismissing(trend.model) && trend.r2 != -Inf # Use the trend curve
        minx, maxx = extrema(xs)
        plotminx, plotmaxx = minx < 1750 ? (1470, 2030) : (1750, 2030)
        if title != "" 
            ax.title = title
        end

        # Fix the log scale
        x = plotminx-minx:plotmaxx-minx
        trend_predictions = predict(trend.model, (; x); 
            interval=:confidence, 
            level=0.95
        )
        # Fix the log scale
        Makie.lines!(ax, plotminx:plotmaxx, exp.(trend_predictions.prediction); 
            linewidth=2, 
            color=:black,
            label="Trend"
        )
        confidence_band = Makie.band!(ax, plotminx:plotmaxx, exp.(trend_predictions.lower), exp.(trend_predictions.upper);
            color=(:grey, 0.3),
        )
        translate!(confidence_band, 0, 0, -10)
    end
    mean_line = Makie.hlines!(ax, geomean(df.EstimatedMass); 
        linewidth=2, 
        label="Geometric\nmean",
        color=:grey,
    )
    translate!(mean_line, 0, 0, -20)

    DataInspector(ax)
end

XTICKS = 1600:150:1900

function plot_subsets(subset_layout, subsets, trends;
    colormap=:Egypt,
    colordata=:colonised,
    colorrange=extrema(skipmissing(getproperty(subsets.all.df, colordata))),
    size=(1600, 900),
    legend=nothing,
    xlabel="Year last seen", 
    ylabel="Mass",
    titlejoin=" ",
    xticks=XTICKS, 
    spinewidth=2, 
    fonts=(; regular="Arial"),
)
    fig = Figure(; size, fonts);
    ax_kw = (; yscale=log10, spinewidth, xlabel, ylabel, xticks,
        xgridwidth=2, ygridwidth=2, 
    )
    axs = map(subset_layout, CartesianIndices(subset_layout)) do key, I
        if isnothing(key)
            ax = Axis(fig[Tuple(I)...])
        else
            sub = subsets[key]
            trend = trends[key]
            ax = Axis(fig[Tuple(I)...]; ax_kw...)
            I[1] == Base.size(subset_layout, 1) || hidexdecorations!(ax; grid=false)
            I[2] == 1 || hideydecorations!(ax; grid=false)
            plot_extinctions!(ax, sub.df;
                title="$(titlecase(string(sub.title))):$(titlejoin)$(titlecase(replace(string(trend.class), "_" => " ")))", 
                legend=Tuple(I) == (1, 1),
                names=:tooltip,
                colormap, trend, ax_kw...
            )
        end
        xlims!(ax, (1470, 2030))
        ylims!(ax, (1.0, 1e6))
        ax
    end
    linkaxes!(axs...)
    if !isnothing(legend)
        I = 1:Base.size(subset_layout, 1), Base.size(subset_layout, 2) + 1 
        Legend(fig[I...], axs[legend.axisnum]; 
            framevisible=false
        )
    end
    return fig
end
