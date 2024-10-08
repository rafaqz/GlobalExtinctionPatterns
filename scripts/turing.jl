using Turing
using GlobalExtinctionPatterns
using GLMakie
using Revise
using DataFrames

@model function simple_extinction_mass(mass, year, year_squared)
    b1 ~ Normal(0, 100)
    b2 ~ Normal(0, 100)
    sigma ~ Exponential(10)
    intercept ~ Normal(0, 100)

    mass_est = intercept .+ year .* b1 .+ year_squared .* b2
    mass ~ MvNormal(mass_est, sigma)
end

@model function extinction_mass(mass, year, year_squared, wasuninhabited, colonised_year)
    b1 ~ Normal(0, 100)
    b2 ~ Normal(0, 100)
    b3 ~ Normal(0, 100)
    b4 ~ Normal(0, 100)
    b5 ~ Normal(0, 100)
    # b6 ~ Normal(0, 10)
    # b7 ~ Normal(0, 10)
    sigma ~ Exponential(10)
    intercept ~ Normal(0, 100)

    # mass_est = intercept .+ year .* b1 .+ year_squared .* b2 .+ wasuninhabited .* b3 .+
        # wasuninhabited .* year_squared .* b4 .+ since_colonised .* b5 .+ since_colonised .* wasuninhabited .* year .* b6 .+ since_colonised .* wasuninhabited  .* year_squared .* b7
    mass_est = intercept .+ 
               year .* b1 .+ 
               year_squared .* b2 .+ 
               wasuninhabited .* b3 .+
               wasuninhabited .* year_squared .* b4 .+ 
               colonised_year .* wasuninhabited .* year .* b5

    mass ~ MvNormal(mass_est, sigma)
end


mass_df = load_mass_table()
mass_df
# Add numerical classes

mass_df.classNum = collect(map(x -> findfirst(==(x), intersect(classes, mass_df.className)) , mass_df.className)),
mass = log.(mass_df.EstimatedMass)
wasuninhabited = mass_df.wasuninhabited
year = (mass_df.yearLastSeen_cleaned .- 1750) ./ 250
year_squared = year .^ 2
colonised_year = (mass_df.colonised .- 1750) ./ 250
since_colonised = (mass_df.yearLastSeen_cleaned .- mass_df.colonised) ./ 250

year_mass_all = extinction_mass(mass, year, year_squared, wasuninhabited, colonised_year)
chain = sample(year_mass_all, NUTS(), 1000)

year_mass_all = extinction_mass(mass, year, year_squared, wasuninhabited, colonised_year)
chain = sample(year_mass_all, NUTS(), 1000)

year_mass_simple = simple_extinction_mass(mass, year, year_squared)
simple_chain = sample(year_mass_simple, NUTS(), 1000)

years = ((1500:2000) .- 1750) ./ 250
years_squared = years .^ 2

fig = let
    fig = Figure()
    axs = []
    for (i, wasuninhabited) in enumerate([false, true]), (j, colonised_year) in  enumerate([-0.5, 0, 0.5])
        b1 = chain[:b1]
        b2 = chain[:b2]
        b3 = chain[:b3]
        b4 = chain[:b4]
        b5 = chain[:b5]
        intercept = chain[:intercept]
        xlabel = i == 2 ? string("Colonised ", convert(Int, colonised_year * 250 + 1750)) : ""
        ylabel = j == 1 ? (wasuninhabited ? "Uninhabited" : "Inhabited") : ""
        ax = Axis(fig[i, j]; xlabel, ylabel, yscale=log10)
        push!(axs, ax)
        # mass_est = intercept .+ year .* b1 .+ year_squared .* b2 .+ wasuninhabited .* b3 .+
            # wasuninhabited .* year_squared .* b4 .+ colonised_year .* wasuninhabited .* year .* b5
        mass_est = intercept .+ years' .* b1 .+ years_squared' .* b2 .+ wasuninhabited .* b3 .+
            wasuninhabited .* years_squared' .* b4 .+ colonised_year .* years_squared' .* b5
        mass_est_mean = mean(mass_est; dims=1)
        mass_est_quant025 = quantile.(eachcol(mass_est), Ref(0.025))
        mass_est_quant975 = quantile.(eachcol(mass_est), Ref(0.975))

        p = Makie.plot!(ax, 1500:2000, exp.(vec(mass_est_mean)))
        Makie.band!(ax, 1500:2000, exp.(mass_est_quant025), exp.(mass_est_quant975); alpha=0.7)
        sub_df = wasuninhabited ? subsets.uninhabited_islands.df : subsets.inhabited_islands.df
        Makie.scatter!(ax, sub_df.yearLastSeen_cleaned, sub_df.EstimatedMass; alpha=0.5)
    end
    linkaxes!(axs...)
    fig
end
save(joinpath(basepath, "images/bayesian_.png"), fig)

fig = let
    b1 = simple_chain[:b1]
    b2 = simple_chain[:b2]
    intercept = simple_chain[:intercept]
    fig = Figure()
    axs = []
    ax = Axis(fig[1, 1]; yscale=log10)
    push!(axs, ax)
    mass_est = intercept .+ years' .* b1 .+ years_squared' .* b2
    mass_est_mean = mean(mass_est; dims=1)
    mass_est_quant025 = quantile.(eachcol(mass_est), Ref(0.025))
    mass_est_quant975 = quantile.(eachcol(mass_est), Ref(0.975))

    p = Makie.plot!(ax, 1500:2000, exp.(vec(mass_est_mean)))
    Makie.band!(ax, 1500:2000, exp.(mass_est_quant025), exp.(mass_est_quant975); alpha=0.7)
    Makie.scatter!(ax, mass_df.yearLastSeen_cleaned, exp.(mass); alpha=0.5)
    fig
end


