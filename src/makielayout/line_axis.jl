using Showoff

bottomleft(bbox::Rect2D{T}) where T = Point2{T}(left(bbox), bottom(bbox))
topleft(bbox::Rect2D{T}) where T = Point2{T}(left(bbox), top(bbox))
bottomright(bbox::Rect2D{T}) where T = Point2{T}(right(bbox), bottom(bbox))
topright(bbox::Rect2D{T}) where T = Point2{T}(right(bbox), top(bbox))

topline(bbox::FRect2D) = (topleft(bbox), topright(bbox))
bottomline(bbox::FRect2D) = (bottomleft(bbox), bottomright(bbox))
leftline(bbox::FRect2D) = (bottomleft(bbox), topleft(bbox))
rightline(bbox::FRect2D) = (bottomright(bbox), topright(bbox))

function line_axis_attributes()
    return Attributes(
        endpoints = (Point2f0(0, 0), Point2f0(100, 0)),
        trimspine = false,
        limits = (0, 540),
        flipped = false,
        flip_vertical_label = false,
        ticksize = 10f0,
        tickwidth = 1f0,
        tickcolor = RGBf0(0, 0, 0),
        tickalign = 0f0,
        ticks = AbstractPlotting.automatic,
        tickformat = AbstractPlotting.automatic,
        ticklabelalign = (:center, :top),
        ticksvisible = true,
        ticklabelrotation = 0f0,
        ticklabelsize = 20f0,
        ticklabelcolor = RGBf0(0, 0, 0),
        ticklabelsvisible = true,
        spinewidth = 1f0,
        label = "label",
        labelsize = 20f0,
        labelcolor = RGBf0(0, 0, 0),
        labelvisible = true,
        ticklabelspace = AbstractPlotting.automatic,
        ticklabelpad = 5f0,
        labelpadding = 15f0,
        reversed = false,
        spinecolor = :black,
        labelfont = "Dejavue Sans",
        ticklabelfont = "Dejavue Sans",
        spinevisible = true
    )
end

function LineAxis(parent::Scene; kwargs...)

    attrs = merge!(Attributes(kwargs), line_axis_attributes())
    decorations = Dict{Symbol, Any}()

    @extract attrs (endpoints, limits, flipped, ticksize, tickwidth,
        tickcolor, tickalign, ticks, tickformat, ticklabelalign, ticklabelrotation, ticksvisible,
        ticklabelspace, ticklabelpad, labelpadding,
        ticklabelsize, ticklabelsvisible, spinewidth, spinecolor, label, labelsize, labelcolor,
        labelfont, ticklabelfont, ticklabelcolor,
        labelvisible, spinevisible, trimspine, flip_vertical_label, reversed)

    pos_extents_horizontal = lift(endpoints) do endpoints
        if endpoints[1][2] == endpoints[2][2]
            horizontal = true
            extents = (endpoints[1][1], endpoints[2][1])
            position = endpoints[1][2]
            return (position, extents, horizontal)
        elseif endpoints[1][1] == endpoints[2][1]
            horizontal = false
            extents = (endpoints[1][2], endpoints[2][2])
            position = endpoints[1][1]
            return (position, extents, horizontal)
        else
            error("Axis endpoints $(endpoints[1]) and $(endpoints[2]) are neither on a horizontal nor vertical line")
        end
    end

    ticksnode = Node(Point2f0[])
    ticklines = linesegments!(
        parent, ticksnode, linewidth = tickwidth, color = tickcolor,
        show_axis = false, visible = ticksvisible
    )[end]
    decorations[:ticklines] = ticklines

    ticklabelannosnode = Node{Vector{Tuple{String, Point2f0}}}([("temp", Point2f0(0, 0))])
    ticklabels = annotations!(
        parent,
        ticklabelannosnode,
        align = ticklabelalign,
        rotation = ticklabelrotation,
        textsize = ticklabelsize,
        font = ticklabelfont,
        color = ticklabelcolor,
        show_axis = false,
        visible = ticklabelsvisible)[end]

    ticklabel_ideal_space = lift(ticklabelannosnode, ticklabelalign, ticklabelrotation, ticklabelfont, ticklabelsvisible, typ=Float32) do args...
        maxwidth = if pos_extents_horizontal[][3]
                # height
                ticklabelsvisible[] ? height(FRect2D(boundingbox(ticklabels))) : 0f0
            else
                # width
                ticklabelsvisible[] ? width(FRect2D(boundingbox(ticklabels))) : 0f0
        end
    end

    attrs[:actual_ticklabelspace] = 0f0
    actual_ticklabelspace = attrs[:actual_ticklabelspace]

    onany(ticklabel_ideal_space, ticklabelspace) do idealspace, space
        s = if space == AbstractPlotting.automatic
            idealspace
        else
            space
        end
        if s != actual_ticklabelspace[]
            actual_ticklabelspace[] = s
        end
    end


    decorations[:ticklabels] = ticklabels

    tickspace = lift(ticksvisible, ticksize, tickalign) do ticksvisible,
            ticksize, tickalign

        return ticksvisible ? max(0f0, ticksize * (1f0 - tickalign)) : 0f0
    end

    labelgap = lift(spinewidth, tickspace, ticklabelsvisible, actual_ticklabelspace,
        ticklabelpad, labelpadding) do spinewidth, tickspace, ticklabelsvisible,
            actual_ticklabelspace, ticklabelpad, labelpadding


        return spinewidth + tickspace +
            (ticklabelsvisible ? actual_ticklabelspace + ticklabelpad : 0f0) +
            labelpadding
    end

    labelpos = lift(pos_extents_horizontal, flipped, labelgap) do (position, extents, horizontal), flipped, labelgap

        # fullgap = tickspace[] + labelgap

        middle = extents[1] + 0.5f0 * (extents[2] - extents[1])

        x_or_y = flipped ? position + labelgap : position - labelgap

        if horizontal
            Point2(middle, x_or_y)
        else
            Point2(x_or_y, middle)
        end
    end

    labelalign = lift(pos_extents_horizontal, flipped, flip_vertical_label) do (position, extents, horizontal), flipped, flip_vertical_label
        if horizontal
            (:center, flipped ? :bottom : :top)
        else
            (:center, if flipped
                    flip_vertical_label ? :bottom : :top
                else
                    flip_vertical_label ? :top : :bottom
                end
            )
        end
    end

    labelrotation = lift(pos_extents_horizontal, flip_vertical_label) do (position, extents, horizontal), flip_vertical_label
        if horizontal
            0f0
        else
            if flip_vertical_label
                Float32(-0.5pi)
            else
                Float32(0.5pi)
            end
        end
    end

    labeltext = text!(
        parent, label, textsize = labelsize, color = labelcolor,
        position = labelpos, show_axis = false, visible = labelvisible,
        align = labelalign, rotation = labelrotation, font = labelfont,
    )[end]

    decorations[:labeltext] = labeltext

    tickvalues = Node(Float32[])

    tickvalues_unfiltered = lift(pos_extents_horizontal, limits, ticks) do (position, extents, horizontal),
            limits, ticks
        get_tickvalues(ticks, limits...)
    end

    tickpositions = Node(Point2f0[])
    tickstrings = Node(String[])

    onany(tickvalues_unfiltered, reversed, tickformat) do tickvalues_unfiltered, reversed, tickformat

        tickstrings_unfiltered = get_ticklabels(tickformat, ticks[], tickvalues_unfiltered)

        position, extents_uncorrected, horizontal = pos_extents_horizontal[]

        extents = reversed ? reverse(extents_uncorrected) : extents_uncorrected

        px_o = extents[1]
        px_width = extents[2] - extents[1]

        lim_o = limits[][1]
        lim_w = limits[][2] - limits[][1]

        # if labels are given manually, it's possible that some of them are outside the displayed limits
        i_values_within_limits = findall(tv -> lim_o <= tv <= (lim_o + lim_w), tickvalues_unfiltered)
        tickvalues[] = tickvalues_unfiltered[i_values_within_limits]

        tick_fractions = (tickvalues[] .- lim_o) ./ lim_w
        tick_scenecoords = px_o .+ px_width .* tick_fractions

        tickpos = if horizontal
            [Point(x, position) for x in tick_scenecoords]
        else
            [Point(position, y) for y in tick_scenecoords]
        end

        # now trigger updates
        tickpositions[] = tickpos

        tickstrings[] = tickstrings_unfiltered[i_values_within_limits]
    end

    onany(tickstrings, labelgap, flipped) do tickstrings, labelgap, flipped
        # tickspace is always updated before labelgap
        # tickpositions are always updated before tickstrings
        # so we don't need to lift those

        position, extents, horizontal = pos_extents_horizontal[]

        nticks = length(tickvalues[])

        ticklabelgap = spinewidth[] + tickspace[] + ticklabelpad[]

        shift = if horizontal
            Point2f0(0f0, flipped ? ticklabelgap : -ticklabelgap)
        else
            Point2f0(flipped ? ticklabelgap : -ticklabelgap, 0f0)
        end

        ticklabelpositions = tickpositions[] .+ Ref(shift)
        ticklabelannosnode[] = collect(zip(tickstrings, ticklabelpositions))
    end

    onany(tickpositions, tickalign, ticksize, spinewidth) do tickpositions,
            tickalign, ticksize, spinewidth

        position, extents, horizontal = pos_extents_horizontal[]

        if horizontal
            tickstarts = [tp + (flipped[] ? -1f0 : 1f0) * Point2f0(0f0, tickalign * ticksize - 0.5f0 * spinewidth) for tp in tickpositions]
            tickends = [t + (flipped[] ? -1f0 : 1f0) * Point2f0(0f0, -ticksize) for t in tickstarts]
            ticksnode[] = interleave_vectors(tickstarts, tickends)
        else
            tickstarts = [tp + (flipped[] ? -1f0 : 1f0) * Point2f0(tickalign * ticksize - 0.5f0 * spinewidth, 0f0) for tp in tickpositions]
            tickends = [t + (flipped[] ? -1f0 : 1f0) * Point2f0(-ticksize, 0f0) for t in tickstarts]
            ticksnode[] = interleave_vectors(tickstarts, tickends)
        end
    end

    linepoints = lift(pos_extents_horizontal, flipped, spinewidth, trimspine, tickpositions, tickwidth) do (position, extents, horizontal),
            flipped, sw, trimspine, tickpositions, tickwidth

        if !trimspine
            if horizontal
                y = position + (flipped ? 1f0 : -1f0) * 0.5f0 * sw
                p1 = Point2f0(extents[1] - sw, y)
                p2 = Point2(extents[2] + sw, y)
                [p1, p2]
            else
                x = position + (flipped ? 1f0 : -1f0) * 0.5f0 * sw
                p1 = Point2f0(x, extents[1] - sw)
                p2 = Point2f0(x, extents[2] + sw)
                [p1, p2]
            end
        else
            [tickpositions[1], tickpositions[end]] .+ [
                (horizontal ? Point2f0(-0.5f0 * tickwidth, 0) : Point2f0(0, -0.5f0 * tickwidth)),
                (horizontal ? Point2f0(0.5f0 * tickwidth, 0) : Point2f0(0, 0.5f0 * tickwidth)),
            ]
        end
    end

    decorations[:axisline] = lines!(parent, linepoints, linewidth = spinewidth, visible = spinevisible,
        color = spinecolor, raw = true)[end]


    protrusion = lift(ticksvisible, label, labelvisible, labelpadding, labelsize, tickalign, spinewidth,
            spinevisible, tickspace, ticklabelsvisible, actual_ticklabelspace, ticklabelpad, labelfont, ticklabelfont) do ticksvisible,
            label, labelvisible, labelpadding, labelsize, tickalign, spinewidth, spinevisible, tickspace, ticklabelsvisible,
            actual_ticklabelspace, ticklabelpad, labelfont, ticklabelfont

        position, extents, horizontal = pos_extents_horizontal[]

        real_labelsize = if iswhitespace(label)
            0f0
        else
            horizontal ? boundingbox(labeltext).widths[2] : boundingbox(labeltext).widths[1]
        end

        labelspace = (labelvisible && !iswhitespace(label)) ? real_labelsize + labelpadding : 0f0
        spinespace = spinevisible ? spinewidth : 0f0
        # tickspace = ticksvisible ? max(0f0, xticksize * (1f0 - xtickalign)) : 0f0
        ticklabelgap = ticklabelsvisible ? actual_ticklabelspace + ticklabelpad : 0f0

        together = spinespace + tickspace + ticklabelgap + labelspace
    end

    # trigger whole pipeline once to fill tickpositions and tickstrings
    # etc to avoid empty ticks bug #69
    limits[] = limits[]

    return (parent = parent,
            protrusion = protrusion,
            attrs = attrs,
            decorations = decorations,
            tickpositions = tickpositions,
            tickvalues = tickvalues,
            tickstrings = tickstrings)

end


function tight_ticklabel_spacing!(la)

    horizontal = if la.attributes.endpoints[][1][2] == la.attributes.endpoints[][2][2]
        true
    elseif la.attributes.endpoints[][1][1] == la.attributes.endpoints[][2][1]
        false
    else
        error("endpoints not on a horizontal or vertical line")
    end

    tls = la.decorations[:ticklabels]
    maxwidth = if horizontal
            # height
            tls.visible[] ? height(FRect2D(boundingbox(tls))) : 0f0
        else
            # width
            tls.visible[] ? width(FRect2D(boundingbox(tls))) : 0f0
    end
    la.attributes.ticklabelspace = maxwidth
end

function iswhitespace(str)
    match(r"^\s+$", str) !== nothing
end

"""
LinearTicks with ideally a number of `n_ideal` tick marks.
"""
struct LinearTicks
    n_ideal::Int

    function LinearTicks(n_ideal)
        if n_ideal <= 0
            error("Ideal number of ticks can't be smaller than 0, but is $n_ideal")
        end
        new(n_ideal)
    end
end
"""
    get_tickvalues(::AbstractPlotting.Automatic, vmin, vmax)

Calls the default tick finding algorithm, which could depend on the current LAxis
state.
"""
get_tickvalues(::AbstractPlotting.Automatic, vmin, vmax) = get_tickvalues(LinearTicks(5), vmin, vmax)


"""
    get_tickvalues(lt::LinearTicks, vmin, vmax)

Runs a common tick finding algorithm to as many ticks as requested by the
`LinearTicks` instance.
"""
get_tickvalues(lt::LinearTicks, vmin, vmax) = locateticks(vmin, vmax, lt.n_ideal)

"""
    get_tickvalues(tup::Tuple{<:Any, <:Any}, vmin, vmax)

Calls `get_tickvalues(tup[1], vmin, vmax)` where the first entry of the tuple
should contain an iterable tick values and the second entry should contain an
iterable of the respective labels.
"""
get_tickvalues(tup::Tuple{<:Any, <:Any}, vmin, vmax) = get_tickvalues(tup[1], vmin, vmax)

"""
    get_tickvalues(tickvalues, vmin, vmax)

Uses tickvalues directly.
"""
get_tickvalues(tickvalues, vmin, vmax) = tickvalues

# there is an opportunity to overload formatters for specific ticks,
# but the generic case doesn't use this and just forwards to a less specific method
"""
    get_ticklabels(formatter, ticks, values)

Forwards to `get_ticklabels(formatter, values)` if no specialization exists.
"""
get_ticklabels(formatter, ticks, values) = get_ticklabels(formatter, values)

"""
    get_ticklabels(::AbstractPlotting.Automatic, tup::Tuple{<:Any, <:Any}, values)

Returns the second entry of `tup`, which should be an iterable of strings, as the tick labels for `values`.
"""
function get_ticklabels(::AbstractPlotting.Automatic, tup::Tuple{<:Any, <:Any}, values)
    n1 = length(tup[1])
    n2 = length(tup[2])
    if n1 != n2
        error("There are $n1 tick values in $(tup[1]) but $n2 tick labels in $(tup[2]).")
    end
    tup[2]
end

"""
    get_ticklabels(::AbstractPlotting.Automatic, values)

Gets tick labels by applying `Showoff.showoff` to `values`.
"""
get_ticklabels(::AbstractPlotting.Automatic, values) = Showoff.showoff(values)

"""
    get_ticklabels(formatfunction::Function, values)

Gets tick labels by applying `formatfunction` to `values`.
"""
get_ticklabels(formatfunction::Function, values) = formatfunction(values)

"""
    get_ticklabels(formatstring::AbstractString, values)

Gets tick labels by formatting each value in `values` according to a `Formatting.format` format string.
"""
get_ticklabels(formatstring::AbstractString, values) = [Formatting.format(formatstring, v) for v in values]

function scale_range(vmin, vmax, n=1, threshold=100)
    dv = abs(vmax - vmin)  # > 0 as nonsingular is called before.
    meanv = (vmax + vmin) / 2
    offset = if abs(meanv) / dv < threshold
        0.0
    else
        copysign(10 ^ (log10(abs(meanv)) ÷ 1), meanv)
    end
    scale = 10 ^ (log10(dv / n) ÷ 1)
    scale, offset
end

function _staircase(steps)
    n = length(steps)
    result = Vector{Float64}(undef, 2n)
    for i in 1:(n-1)
        @inbounds result[i] = 0.1 * steps[i]
    end
    for i in 1:n
        @inbounds result[i+(n-1)] = steps[i]
    end
    result[end] = 10 * steps[2]
    return result
    # [0.1 .* steps[1:end-1]; steps; 10 .* steps[2]]
end


struct EdgeInteger
    step::Float64
    offset::Float64

    function EdgeInteger(step, offset)
        if step <= 0
            error("Step must be positive")
        end
        new(step, abs(offset))
    end
end

function closeto(e::EdgeInteger, ms, edge)
    tol = if e.offset > 0
        digits = log10(e.offset / e.step)
        tol = max(1e-10, 10 ^ (digits - 12))
        min(0.4999, tol)
    else
        1e-10
    end
    abs(ms - edge) < tol
end

function le(e::EdgeInteger, x)
    # 'Return the largest n: n*step <= x.'
    d, m = divrem(x, e.step)
    if closeto(e, m / e.step, 1)
        d + 1
    else
        d
    end
end

function ge(e::EdgeInteger, x)
    # 'Return the smallest n: n*step >= x.'
    d, m = divrem(x, e.step)
    if closeto(e, m / e.step, 0)
        d
    else
        d + 1
    end
end


"""
A cheaper function that tries to come up with usable tick locations for a given value range
"""
function locateticks(vmin, vmax, n_ideal::Int, _integer::Bool = false, _min_n_ticks::Int = 2)

    _steps = (1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0)
    _extended_steps = _staircase(_steps)

    scale, offset = scale_range(vmin, vmax, n_ideal)

    _vmin = vmin - offset
    _vmax = vmax - offset

    raw_step = (_vmax - _vmin) / n_ideal

    steps = _extended_steps .* scale

    if _integer
        # For steps > 1, keep only integer values.
        filter!(steps) do i
            (i < 1) || (abs(i - round(i)) < 0.001)
        end
    end

    #istep = np.nonzero(steps >= raw_step)[0][0]
    istep = findfirst(1:length(steps)) do i
        @inbounds return steps[i] >= raw_step
    end
    ticks = 1.0:0.1:0.0
    for istep in istep:-1:1
        step = steps[istep]

        if _integer && (floor(_vmax) - ceil(_vmin) >= _min_n_ticks - 1)
            step = max(1, step)
        end
        best_vmin = (_vmin ÷ step) * step

        # Find tick locations spanning the vmin-vmax range, taking into
        # account degradation of precision when there is a large offset.
        # The edge ticks beyond vmin and/or vmax are needed for the
        # "round_numbers" autolimit mode.
        edge = EdgeInteger(step, offset)
        low = le(edge, _vmin - best_vmin)
        high = ge(edge, _vmax - best_vmin)
        ticks = (low:high) .* step .+ best_vmin
        # Count only the ticks that will be displayed.
        # nticks = sum((ticks .<= _vmax) .& (ticks .>= _vmin))

        # manual sum because broadcasting was slow
        nticks = 0
        for t in ticks
            if _vmin <= t <= _vmax
                nticks += 1
            end
        end

        if nticks >= _min_n_ticks
            break
        end
    end

    ticks = ticks .+ offset #(first(ticks) + offset):step(ticks):(last(ticks) + offset)
    vals = filter(x -> vmin <= x <= vmax, ticks)

    # for some reason, the values coming out of this method sometimes are ever so slightly off from
    # their intended decimal representation, causing printed values like
    # 0.08000000001 instead of 0.08
    # so here we round off the numbers to the required number of digits after the decimal point
    exponent = floor(Int, minimum(log10.(abs.(diff(vals)))))
    round.(vals, digits = max(0, -exponent+1))
end


function locateticks(vmin, vmax, width_px, ideal_tick_distance::Float32, _integer::Bool = false, _min_n_ticks::Int = 2)
    # how many ticks would ideally fit?
    n_ideal = round(Int, width_px / ideal_tick_distance) + 1
    locateticks(vmin, vmax, n_ideal, _integer, _min_n_ticks)
end


function interleave_vectors(vec1::Vector{T}, vec2::Vector{T}) where T
    n = length(vec1)
    @assert n == length(vec2)

    vec = Vector{T}(undef, 2 * n)
    @inbounds for i in 1:n
        k = 2(i - 1)
        vec[k + 1] = vec1[i]
        vec[k + 2] = vec2[i]
    end
    vec
end


left(rect::Rect{2}) = minimum(rect)[1]
right(rect::Rect{2}) = maximum(rect)[1]
bottom(rect::Rect{2}) = minimum(rect)[2]
top(rect::Rect{2}) = maximum(rect)[2]


bottomleft(bbox::Rect2D{T}) where T = Point2{T}(left(bbox), bottom(bbox))
topleft(bbox::Rect2D{T}) where T = Point2{T}(left(bbox), top(bbox))
bottomright(bbox::Rect2D{T}) where T = Point2{T}(right(bbox), bottom(bbox))
topright(bbox::Rect2D{T}) where T = Point2{T}(right(bbox), top(bbox))

topline(bbox::FRect2D) = (topleft(bbox), topright(bbox))
bottomline(bbox::FRect2D) = (bottomleft(bbox), bottomright(bbox))
leftline(bbox::FRect2D) = (bottomleft(bbox), topleft(bbox))
rightline(bbox::FRect2D) = (bottomright(bbox), topright(bbox))


function shrinkbymargin(rect, margin)
    IRect((rect.origin .+ margin), (rect.widths .- 2 .* margin))
end

function AbstractPlotting.limits(r::Rect{N, T}) where {N, T}
    ows = r.origin .+ r.widths
    ntuple(i -> (r.origin[i], ows[i]), N)
    # tuple(zip(r.origin, ows)...)
end

function AbstractPlotting.limits(r::Rect{N, T}, dim::Int) where {N, T}
    o = r.origin[dim]
    w = r.widths[dim]
    (o, o + w)
end

xlimits(r::Rect{2}) = AbstractPlotting.limits(r, 1)
ylimits(r::Rect{2}) = AbstractPlotting.limits(r, 2)