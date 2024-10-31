#
# We want summary of geometric mean to display 
# with regular masses rather than log masses
# Unfortunately ther is no built-in geometric std or confint
geostd(xs) = exp(std(Iterators.map(log, xs)))
function geosummary(xs)
    # Convert to log masses
    lxs = map(log, xs)
    mn = mean(lxs)
    st = std(lxs)
    n = length(xs)
    # Assume standard error is fine because n is large
    sterr = st / sqrt(n)

    # Return mean, std, n and confidence interval converted back to regular mass
    return (mean=exp(mn), std=exp(st), n, lower=exp(mn - 1.96sterr), upper=exp(mn + 1.96sterr))
end

function classify_trend(x_init, y;
    significant=0.05,
)
    # Standardise timeline between zero and one
    if length(x_init) <= 2
        return (; class=:none, r2=missing, α0=missing, α1=missing, α2=missing, p_α0=missing, p_α1=missing, p_α2=missing, model=missing)
    end
    xmin, xmax = extrema(x_init)
    x = (x_init .- xmin)

    model = lm(@formula(y ~ x + x^2), (; x, y))
    ct = coeftable(model)
    α0, α1, α2 = ct.cols[1]
    p_α0, p_α1, p_α2 = ct.cols[ct.pvalcol]

    Xm = mean(x)
    δ = (maximum(x) - minimum(x)) * 0.25

    Y(x) = α0 + x * α1 + α2 * x^2
    Ẏ(x) = α1 + 2 * α2 * x
    γ̇(x) = (-12α2^2 * (2α2 * x + α1)) / (1 + (2α2 * x + α1)^2)^2

    velocity = Ẏ(Xm)
    # Is the squared term sigificant
    constant_threashold = 0.1
    class = if (p_α1 < significant) && (p_α2 < significant) # Nonlinear
        if (Ẏ(Xm - δ) > 0 && Ẏ(Xm + δ) > 0)
            acceleration = sign(γ̇(Xm)) * sign(α2)
            acceleration < 0 ? :accelerated_increase : :decelerated_increase
        elseif (Ẏ(Xm - δ) < 0 && Ẏ(Xm + δ) < 0)
            acceleration = sign(γ̇(Xm)) * sign(α2)
            acceleration < 0 ? :accelerated_decline : :decelerated_decline
        else
            α2 > 0 ? :convex : :concave
        end
    elseif p_α1 < significant
        model = lm(@formula(y ~ x), (; x, y))
        α0, α1 = ct.cols[1]
        p_α0, p_α1 = ct.cols[ct.pvalcol]
        if p_α1 < significant
            α1 > 0 ? :constant_increase : :constant_decline
        else
            :stable
        end
    elseif p_α2 < significant
        model = lm(@formula(y ~ x^2), (; x, y))
        if p_α1 < significant
            α2 > 0 ? :convex : :concave
        else
            model = lm(@formula(y ~ x), (; x, y))
            :stable
        end
    else # Try linear only
        model1 = lm(@formula(y ~ x), (; x, y))
        ct = coeftable(model1)
        α0, α1 = ct.cols[1]
        p_α0, p_α1 = ct.cols[ct.pvalcol]
        if (p_α1 < significant)
            α2 = missing
            p_α2 = missing
            model = model1
            velocity = abs(α1)
            α1 > 0 ? :constant_increase : :constant_decline
        else # Try polynomial only
            model2 = lm(@formula(y ~ x^2), (; x, y))
            ct = coeftable(model2)
            α0, α1 = ct.cols[1]
            p_α0, p_α1 = ct.cols[ct.pvalcol]
            acceleration = sign(α1)
            if p_α1 < significant
                α2 = missing
                p_α2 = missing
                model = model2
                α1 > 0 ? :convex : :concave
            else
                model = model1
                :stable
            end
        end
    end

    (; class, model, r2=r2(model))
end
