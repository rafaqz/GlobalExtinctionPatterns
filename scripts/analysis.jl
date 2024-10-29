deleteat!(Base.LOAD_PATH, 2:3)

using Revise
using CSV
using DataFrames
using ColorSchemes
using Colors
using StatsBase
using CairoMakie
using GLM

using GlobalExtinctionPatterns
const GEP = GlobalExtinctionPatterns

basepath = GlobalExtinctionPatterns.basepath
datapath = joinpath(basepath, "data")
classes = ["AVES", "MAMMALIA", "REPTILIA"]
cause_colors = map(i -> get(ColorSchemes.Bay, i/4), 1:4)

mass_df = load_mass_table(; classes)
mass_df.threat_groups = get_threat_groups(mass_df, datapath)
mass_df.threat_codes = get_threat_codes(mass_df, datapath)
mass_df = GEP.add_threat_categories!(mass_df)
mass_df.classNum = collect(map(x -> findfirst(==(x), intersect(classes, mass_df.className)) , mass_df.className))
subsets = get_subsets(mass_df)

# Subset mass means
geometric_means = map(subsets) do (; df)
    geomean(df.EstimatedMass)
end
geometric_summary = map(subsets) do (; df)
    GEP.geosummary(df.EstimatedMass)
end
geometric_means |> pairs
geometric_summary |> pairs

mass_df.log_body = log.(mass_df.EstimatedMass)
mass_df.late = mass_df.colonised .>= 1750
mass_df.inhabited = .!(mass_df.wasuninhabited)
mass_df.years .= mass_df.yearLastSeen_cleaned .- minimum(mass_df.yearLastSeen_cleaned)
mass_df.years2 .= mass_df.years .^ 2
sort!(mass_df, :years)

# Relationship between mass and history

# All terms. The early/late distinction is never significant
# model = lm(@formula(log_body ~ late + inhabited + years + late & years + inhabited & years + years2 + years2 & late + years2 & inhabited), mass_df)
#=
StatsModels.TableRegressionModel{LinearModel{GLM.LmResp{Vector{Float64}}, GLM.DensePredChol{Float64, LinearAlgebra.CholeskyPivoted{Float64, Matrix{Float64}, Vector{Int64}}}}, Matrix{Float64}}

log_body ~ 1 + late + inhabited + years + years2 + late & years + inhabited & years + years2 & late + years2 & inhabited

Coefficients:
──────────────────────────────────────────────────────────────────────────────────────
                          Coef.  Std. Error      t  Pr(>|t|)    Lower 95%    Upper 95%
──────────────────────────────────────────────────────────────────────────────────────
(Intercept)          2.4105      1.03664      2.33    0.0209   0.368339     4.45265
late                 1.47535     2.30277      0.64    0.5223  -3.06107      6.01176
inhabited            3.92412     1.12954      3.47    0.0006   1.69896      6.14929
years                0.0367447   0.00798403   4.60    <1e-05   0.0210163    0.0524731
years2              -7.17404e-5  1.41786e-5  -5.06    <1e-06  -9.96719e-5  -4.38089e-5
late & years        -0.00885571  0.0128769   -0.69    0.4923  -0.0342229    0.0165115
inhabited & years   -0.0386575   0.00855137  -4.52    <1e-05  -0.0555036   -0.0218115
years2 & late        1.29793e-5  1.90479e-5   0.68    0.4963  -2.45447e-5   5.05032e-5
years2 & inhabited   6.71075e-5  1.52774e-5   4.39    <1e-04   3.70112e-5   9.72038e-5
──────────────────────────────────────────────────────────────────────────────────────
=# 

# Selected model
model = lm(@formula(log_body ~ inhabited + years + inhabited & years + years2 + years2 & inhabited), mass_df)

# plot the 4 facets
fig = Figure()
for j in 1:2, k in 1:2
    data = dat[dat.late .== j.-1 .&& dat.inhabited .== k.-1,:]
    p = predict(model, data, interval = :confidence)
    axis = Axis(fig[j,k])
    band!(axis, data.years, p.lower, p.upper, color = :lightgrey)
    lines!(axis, data.years, p.prediction, color = :black)
    scatter!(axis, data.years, data.body, color = :red)
end
fig

# Relationship between mass and threat
mass_df.invasive_threat .& mass_df.human_threat
mean(mass_df.log_body[mass_df.invasive_threat])
mean(mass_df.log_body[mass_df.lcc_threat])
mean(mass_df.log_body[mass_df.other_threat])
mean(mass_df.log_body[mass_df.human_threat])

only_one_threat = mass_df.human_threat .+ mass_df.lcc_threat .+ mass_df.invasive_threat .== 1
mass_df.human_threat .| only_one_threat 

model2 = lm(@formula(log_body ~ human_threat + invasive_threat + lcc_threat), mass_df)
