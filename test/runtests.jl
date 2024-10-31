using GlobalExtinctionPatterns, Test, Random

@testset "test Rigal method trends" begin
    Random.seed!(1234)
    n = 20
    x = range(0, 1, n)
    trends = (;
        # Without some added noise the floating point error might be significant
        stable = range(0.5, 0.5, n) .+ rand(n) .* 0.01,
        constant_increase = range(0, 1, n) .+ rand(n) .* 0.01,
        constant_decline = range(1, 0, n) .+ rand(n) .* 0.01,
        concave = sin.(range(0, π, n)),
        convex = 1 .- sin.(range(0, π, n)),
        accelerated_increase = range(0, 1, n) .+ range(0, 1, n) .^ 2,
        accelerated_decline = range(1, 0, n) .+ 1 .- range(0, 1, n) .^ 2,
        decelerated_increase = range(0, 1, n) .+ 1 .- range(1, 0, n) .^ 2,
        decelerated_decline = range(1, 0, n) .+ range(1, 0, n) .^ 2,
    )
    classifications = map(y -> classify_trend(x, y), trends)

    keys(trends)
    map(x -> x.class, Tuple(classifications))

    @test keys(trends) == map(x -> x.class, Tuple(classifications))
end

# Draw a labelled figure of the classifications
# using GLMakie
# fig = Figure()
# ax = Axis(fig[1, 1])
# foreach(trends, keys(trends)) do trend, title
#     text = replace(string(title), '_' => ' ')
#     Makie.lines!(ax, x, trend; label=text)
#     Makie.text!(ax, 0.368, trend[8]; text, align=(:center, :center))
# end
