using Turing
using GlobalExtinctionPatterns
using GLMakie

mass_df = load_mass_table()

@model function extincion_mass(mass, year, year_squared, wasuninhabited, colonised_year)
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
    mass_est = intercept .+ year .* b1 .+ year_squared .* b2 .+ wasuninhabited .* b3 .+ 
        wasuninhabited .* year_squared .* b4 .+ colonised_year .* wasuninhabited .* year .* b5

    mass ~ MvNormal(mass_est, sigma)        
end

mass = log.(mass_df.EstimatedMass)
wasuninhabited = mass_df.wasuninhabited
year = (mass_df.yearLastSeen_cleaned .- 1750) ./ 250
year_squared = year .^ 2
colonised_year = (mass_df.colonised .- 1750) ./ 250
since_colonised = (mass_df.yearLastSeen_cleaned .- mass_df.colonised) ./ 250

year_mass_all = extincion_mass(mass, year, year_squared, wasuninhabited, colonised_year)
chain = sample(year_mass_all, NUTS(), 1000)
chain

years = ((1500:2000) .- 1750) ./ 250
years_squared = years .^ 2
b1 = chain[:b1] 
b2 = chain[:b2]
b3 = chain[:b3]
b4 = chain[:b4]
b5 = chain[:b5]
# b6 = chain[:b6]
# b7 = chain[:b7]
intercept = chain[:intercept]
chain

# mass_est = intercept .+ years' .* b1 .+ (years .^ 2)' .* b2
fig = Figure()
axs = []
for (i, wasuninhabited) in enumerate([false, true]), (j, colonised_year) in  enumerate([-0.5, 0, 0.5])
    xlabel = i == 2 ? string(colonised_year * 250 + 1750) : "" 
    ylabel = j == 1 ? (wasuninhabited ? "uninhabited" : "inhabited") : ""
    ax = Axis(fig[i, j]; xlabel, ylabel)
    push!(axs, ax)
    # mass_est = intercept .+ year .* b1 .+ year_squared .* b2 .+ wasuninhabited .* b3 .+ 
        # wasuninhabited .* year_squared .* b4 .+ colonised_year .* wasuninhabited .* year .* b5
    mass_est = intercept .+ years' .* b1 .+ years_squared' .* b2 .+ wasuninhabited .* b3 .+ 
        wasuninhabited .* years_squared' .* b4 .+ colonised_year .* years_squared' .* b5
    mass_est_mean = mean(mass_est; dims=1)
    mass_est_quant025 = quantile.(eachcol(mass_est), Ref(0.025))
    mass_est_quant975 = quantile.(eachcol(mass_est), Ref(0.975))

    p = Makie.plot!(ax, 1500:2000, vec(mass_est_mean))
    Makie.band!(ax, 1500:2000, mass_est_quant025, mass_est_quant975)
end
linkaxes!(axs...)



