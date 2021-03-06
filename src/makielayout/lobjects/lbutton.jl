function LButton(scene::Scene; bbox = nothing, kwargs...)

    default_attrs = default_attributes(LButton, scene).attributes
    theme_attrs = subtheme(scene, :LButton)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (padding, textsize, label, font, halign, valign, cornerradius,
        cornersegments, strokewidth, strokecolor, buttoncolor,
        labelcolor, labelcolor_hover, labelcolor_active,
        buttoncolor_active, buttoncolor_hover, clicks)

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables(LButton, attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox)

    textpos = Node(Point2f0(0, 0))

    subarea = lift(layoutobservables.computedbbox) do bbox
        IRect2D(bbox)
    end
    subscene = Scene(scene, subarea, camera=campixel!)



    # buttonrect is without the left bottom offset of the bbox
    buttonrect = lift(layoutobservables.computedbbox) do bbox
        BBox(0, width(bbox), 0, height(bbox))
    end

    on(buttonrect) do rect
        textpos[] = Point2f0(left(rect) + 0.5f0 * width(rect), bottom(rect) + 0.5f0 * height(rect))
    end

    roundedrectpoints = lift(roundedrectvertices, buttonrect, cornerradius, cornersegments)

    bcolor = Node{Any}(buttoncolor[])
    button = poly!(subscene, roundedrectpoints, strokewidth = strokewidth, strokecolor = strokecolor,
        color = bcolor, raw = true)[end]
    decorations[:button] = button




    lcolor = Node{Any}(labelcolor[])
    labeltext = text!(subscene, label, position = textpos, textsize = textsize, font = font,
        color = lcolor, align = (:center, :center), raw = true)[end]

    # move text in front of background to be sure it's not occluded
    translate!(labeltext, 0, 0, 1)


    onany(label, textsize, font, padding) do label, textsize, font, padding
        textbb = FRect2D(boundingbox(labeltext))
        autowidth = width(textbb) + padding[1] + padding[2]
        autoheight = height(textbb) + padding[3] + padding[4]
        layoutobservables.autosize[] = (autowidth, autoheight)
    end



    mousestate = addmousestate!(scene, button, labeltext)

    onmouseover(mousestate) do state
        bcolor[] = buttoncolor_hover[]
        lcolor[] = labelcolor_hover[]
    end

    onmouseout(mousestate) do state
        bcolor[] = buttoncolor[]
        lcolor[] = labelcolor[]
    end

    onmouseleftdown(mousestate) do state
        bcolor[] = buttoncolor_active[]
        lcolor[] = labelcolor_active[]
    end

    onmouseleftclick(mousestate) do state
        clicks[] = clicks[] + 1
    end

    label[] = label[]
    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    LButton(scene, layoutobservables, attrs, decorations)
end
