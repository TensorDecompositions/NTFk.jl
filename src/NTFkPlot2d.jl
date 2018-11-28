import Gadfly
import Measures
import Compose
import TensorToolbox
import TensorDecompositions

function plot2dtensorcomponents(t::TensorDecompositions.Tucker, dim::Integer=1; quiet::Bool=false, hsize=8Compose.inch, vsize=4Compose.inch, dpi::Integer=imagedpi, figuredir::String=".", filename::String="", title::String="", xtitle::String="", ytitle::String="", ymin=nothing, ymax=nothing, gm=[], timescale::Bool=true,  datestart=nothing, dateend=nothing, dateincrement::String="Dates.Day", code::Bool=false, order=gettensorcomponentorder(t, dim; method=:factormagnitude), filter=vec(1:length(order)), xmin=datestart, xmax=dateend, transform=nothing, linewidth=2Gadfly.pt, separate::Bool=false)
	recursivemkdir(figuredir; filename=false)
	recursivemkdir(filename)
	csize = TensorToolbox.mrank(t.core)
	ndimensons = length(csize)
	@assert dim >= 1 && dim <= ndimensons
	crank = csize[dim]
	nx, ny = size(t.factors[dim])
	if datestart != nothing
		if dateend == nothing
			xvalues = datestart .+ vec(collect(eval(parse(dateincrement))(0):eval(parse(dateincrement))(1):eval(parse(dateincrement))(nx-1)))
		else
			xvalues = datestart .+ (vec(collect(1:nx)) ./ nx .* (dateend .- datestart))
		end
	else
		if xmax == nothing
			xmax = 1
		end
		xvalues = timescale ? vec(collect(xmax/nx:xmax/nx:xmax)) : vec(collect(1:nx))
	end
	ncomponents = length(filter)
	loopcolors = ncomponents > ncolors ? true : false
	# if loopcolors
	# 	colorloops = convert(Int64, floor(ncomponents / ncolors))
	# end
	componentnames = map(i->"T$i", filter)
	p = t.factors[dim]
	if transform != nothing
		p = transform.(p)
	end
	pl = Vector{Any}(ncomponents)
	for i = 1:ncomponents
		cc = loopcolors ? parse(Colors.Colorant, colors[(i-1)%ncolors+1]) : parse(Colors.Colorant, colors[i])
		pl[i] = Gadfly.layer(x=xvalues, y=p[:, order[filter[i]]], Gadfly.Geom.line(), Gadfly.Theme(line_width=linewidth, default_color=cc))
	end
	# @show [repeat(colors, colorloops); colors[1:(ncomponents - colorloops * ncolors)]]
	# tc = loopcolors ? [Gadfly.Guide.manual_color_key("", componentnames, [repeat(colors, colorloops); colors[1:(ncomponents - colorloops * ncolors)]])] : [Gadfly.Guide.manual_color_key("", componentnames, colors[1:ncomponents])] # this does not work
	tc = loopcolors ? [] : [Gadfly.Guide.manual_color_key("", componentnames, colors[1:ncomponents])]
	if code
		return [pl..., Gadfly.Guide.title(title), Gadfly.Guide.XLabel(xtitle), Gadfly.Guide.YLabel(ytitle), gm..., tc..., Gadfly.Coord.Cartesian(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax)]
	end
	if separate
		for i = 1:ncomponents
			tt = title == "" ? title : title * ": Signal #$i"
			ff = Gadfly.plot(Gadfly.layer(x=xvalues, y=p[:, order[filter[i]]], Gadfly.Geom.line(), Gadfly.Theme(line_width=linewidth, default_color=parse(Colors.Colorant, "red"))), Gadfly.Guide.title(tt), Gadfly.Guide.XLabel(xtitle), Gadfly.Guide.YLabel(ytitle), gm..., Gadfly.Coord.Cartesian(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax))
			!quiet && (display(ff); println())
			fs = split(filename, ".")
			fn = fs[1] * "-$(lpad(order[filter[i]],4,0))." * fs[2]
			Gadfly.draw(Gadfly.PNG(joinpath(figuredir, fn), hsize, vsize, dpi=dpi), ff)
		end
	end
	ff = Gadfly.plot(pl..., Gadfly.Guide.title(title), Gadfly.Guide.XLabel(xtitle), Gadfly.Guide.YLabel(ytitle), gm..., tc..., Gadfly.Coord.Cartesian(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax))
	!quiet && (display(ff); println())
	if filename != ""
		Gadfly.draw(Gadfly.PNG(joinpath(figuredir, filename), hsize, vsize, dpi=dpi), ff)
	end
	return ff
end

function plot2dmodtensorcomponents(t::TensorDecompositions.Tucker, dim::Integer=1, functionname::String="mean"; quiet::Bool=false, hsize=8Compose.inch, vsize=4Compose.inch, dpi::Integer=imagedpi, figuredir::String=".", filename::String="", title::String="", xtitle::String="", ytitle::String="", ymin=nothing, ymax=nothing, gm=[], linewidth=2Gadfly.pt, timescale::Bool=true, datestart=nothing, dateend=nothing, dateincrement::String="Dates.Day", code::Bool=false, order=gettensorcomponentorder(t, dim; method=:factormagnitude), xmin=datestart, xmax=dateend, transform=nothing)
	recursivemkdir(figuredir; filename=false)
	recursivemkdir(filename)
	csize = TensorToolbox.mrank(t.core)
	ndimensons = length(csize)
	@assert dim >= 1 && dim <= ndimensons
	crank = csize[dim]
	loopcolors = crank > ncolors ? true : false
	nx, ny = size(t.factors[dim])
	if datestart != nothing
		if dateend == nothing
			xvalues = datestart .+ vec(collect(eval(parse(dateincrement))(0):eval(parse(dateincrement))(1):eval(parse(dateincrement))(nx-1)))
		else
			xvalues = datestart .+ (vec(collect(1:nx)) ./nx .* (dateend .- datestart))
		end
		xmin=minimum(xvalues)
		xmax=maximum(xvalues)
	else
		if xmax == nothing
			xmax = 1
		end
		xvalues = timescale ? vec(collect(xmax/nx:xmax/nx:xmax)) : vec(collect(1:nx))
	end
	componentnames = map(i->"T$i", 1:crank)
	dp = Vector{Int64}(0)
	for i = 1:ndimensons
		if i != dim
			push!(dp, i)
		end
	end
	pl = Vector{Any}(crank)
	tt = deepcopy(t)
	for (i, o) = enumerate(order)
		for j = 1:crank
			if o !== j
				nt = ntuple(k->(k == dim ? j : Colon()), ndimensons)
				tt.core[nt...] .= 0
			end
		end
		X2 = TensorDecompositions.compose(tt)
		tt.core .= t.core
		tm = eval(parse(functionname))(X2, dp)
		if transform != nothing
			tm = transform.(tm)
		end
		cc = loopcolors ? parse(Colors.Colorant, colors[(i-1)%ncolors+1]) : parse(Colors.Colorant, colors[i])
		pl[i] = Gadfly.layer(x=xvalues, y=tm, Gadfly.Geom.line(), Gadfly.Theme(line_width=linewidth, default_color=cc))
	end
	tc = loopcolors ? [] : [Gadfly.Guide.manual_color_key("", componentnames, colors[1:crank])]
	if code
		return [pl..., Gadfly.Guide.title(title), Gadfly.Guide.XLabel(xtitle), Gadfly.Guide.YLabel(ytitle), gm..., Gadfly.Coord.Cartesian(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax), tc...]
	end
	ff = Gadfly.plot(pl..., Gadfly.Guide.title(title), Gadfly.Guide.XLabel(xtitle), Gadfly.Guide.YLabel(ytitle), gm..., Gadfly.Coord.Cartesian(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax), tc...)
	!quiet && (display(ff); println())
	if filename != ""
		Gadfly.draw(Gadfly.PNG(joinpath(figuredir, filename), hsize, vsize, dpi=dpi), ff)
	end
	return ff
end

function plot2dmodtensorcomponents(X::Array, t::TensorDecompositions.Tucker, dim::Integer=1, functionname1::String="mean", functionname2::String="mean"; quiet=false, hsize=8Compose.inch, vsize=4Compose.inch, dpi::Integer=imagedpi, figuredir::String=".", filename::String="", title::String="", xtitle::String="", ytitle::String="", ymin=nothing, ymax=nothing, gm=[], linewidth=2Gadfly.pt, timescale::Bool=true, datestart=nothing, dateend=nothing, dateincrement::String="Dates.Day", code::Bool=false, order=gettensorcomponentorder(t, dim; method=:factormagnitude), xmin=datestart, xmax=dateend, transform=nothing)
	csize = TensorToolbox.mrank(t.core)
	recursivemkdir(figuredir; filename=false)
	recursivemkdir(filename)
	ndimensons = length(csize)
	@assert dim >= 1 && dim <= ndimensons
	crank = csize[dim]
	loopcolors = crank > ncolors ? true : false
	nx, ny = size(t.factors[dim])
	if datestart != nothing
		if dateend == nothing
			xvalues = datestart .+ vec(collect(eval(parse(dateincrement))(0):eval(parse(dateincrement))(1):eval(parse(dateincrement))(nx-1)))
		else
			xvalues = datestart .+ (vec(collect(1:nx)) ./nx .* (dateend .- datestart))
		end
		xmin=minimum(xvalues)
		xmax=maximum(xvalues)
	else
		if xmax == nothing
			xmax = 1
		end
		xvalues = timescale ? vec(collect(xmax/nx:xmax/nx:xmax)) : vec(collect(1:nx))
	end
	componentnames = map(i->"T$i", 1:crank)
	dp = Vector{Int64}(0)
	for i = 1:ndimensons
		if i != dim
			push!(dp, i)
		end
	end
	pl = Vector{Any}(crank+2)
	tt = deepcopy(t)
	for (i, o) = enumerate(order)
		for j = 1:crank
			if o !== j
				nt = ntuple(k->(k == dim ? j : Colon()), ndimensons)
				tt.core[nt...] .= 0
			end
		end
		X2 = TensorDecompositions.compose(tt)
		tt.core .= t.core
		tm = eval(parse(functionname1))(X2, dp)
		if transform != nothing
			tm = transform.(tm)
		end
		cc = loopcolors ? parse(Colors.Colorant, colors[(i-1)%ncolors+1]) : parse(Colors.Colorant, colors[i])
		pl[i] = Gadfly.layer(x=xvalues, y=tm, Gadfly.Geom.line(), Gadfly.Theme(line_width=linewidth, default_color=cc))
	end
	tm = map(j->eval(parse(functionname2))(vec(X[ntuple(k->(k == dim ? j : Colon()), ndimensons)...])), 1:nx)
	pl[crank+1] = Gadfly.layer(x=xvalues, y=tm, Gadfly.Geom.line(), Gadfly.Theme(line_width=linewidth+1Gadfly.pt, line_style=:dot, default_color=parse(Colors.Colorant, "gray")))
	Xe = TensorDecompositions.compose(t)
	tm = map(j->eval(parse(functionname2))(vec(Xe[ntuple(k->(k == dim ? j : Colon()), ndimensons)...])), 1:nx)
	pl[crank+2] = Gadfly.layer(x=xvalues, y=tm, Gadfly.Geom.line(), Gadfly.Theme(line_width=linewidth, default_color=parse(Colors.Colorant, "gray85")))
	tc = loopcolors ? [] : [Gadfly.Guide.manual_color_key("", [componentnames; "Est."; "True"], [colors[1:crank]; "gray85"; "gray"])]
	if code
		return [pl..., Gadfly.Guide.title(title), Gadfly.Guide.XLabel(xtitle), Gadfly.Guide.YLabel(ytitle), gm..., Gadfly.Coord.Cartesian(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax), tc...]
	end
	ff = Gadfly.plot(pl..., Gadfly.Guide.title(title), Gadfly.Guide.XLabel(xtitle), Gadfly.Guide.YLabel(ytitle), gm..., Gadfly.Coord.Cartesian(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax), tc...)
	!quiet && (display(ff); println())
	if filename != ""
		Gadfly.draw(Gadfly.PNG(joinpath(figuredir, filename), hsize, vsize, dpi=dpi), ff)
	end
	return ff
end

"""
colors=[parse(Colors.Colorant, "green"), parse(Colors.Colorant, "orange"), parse(Colors.Colorant, "blue"), parse(Colors.Colorant, "gray")]
gm=[Gadfly.Guide.manual_color_key("", ["Oil", "Gas", "Water"], colors[1:3]), Gadfly.Theme(major_label_font_size=16Gadfly.pt, key_label_font_size=14Gadfly.pt, minor_label_font_size=12Gadfly.pt)]
"""
function plot2d(T::Array, Te::Array=T; quiet::Bool=false, wellnames=nothing, Tmax=nothing, Tmin=nothing, xtitle::String="", ytitle::String="", titletext::String="", figuredir::String="results", hsize=8Gadfly.inch, vsize=4Gadfly.inch, dpi::Integer=imagedpi, keyword::String="", dimname::String="Column", colors=NTFk.colors, gm=[Gadfly.Theme(major_label_font_size=16Gadfly.pt, key_label_font_size=14Gadfly.pt, minor_label_font_size=12Gadfly.pt)], linewidth::Measures.Length{:mm,Float64}=2Gadfly.pt, xaxis=1:size(Te,2), xmin=nothing, xmax=nothing, ymin=nothing, ymax=nothing, xintercept=[])
	recursivemkdir(figuredir)
	c = size(T)
	if length(c) == 2
		nlayers = 1
	else
		nlayers = c[3]
	end
	if wellnames != nothing
		@assert length(wellnames) == c[1]
	end
	@assert c == size(Te)
	@assert length(vec(collect(xaxis))) == c[2]
	if Tmax != nothing && Tmin != nothing
		@assert size(Tmax) == size(Tmin)
		@assert size(Tmax, 1) == c[1]
		@assert size(Tmax, 2) == c[3]
		append = ""
	else
		if maximum(T) <= 1. && maximum(Te) <= 1.
			append = "_normalized"
		else
			append = ""
		end
	end
	if keyword != ""
		append *= "_$(keyword)"
	end
	for w = 1:c[1]
		!quiet && (if wellnames != nothing
			println("$dimname $w : $(wellnames[w])")
		else
			println("$dimname $w")
		end)
		p = Vector{Any}(nlayers * 2)
		pc = 1
		for i = 1:nlayers
			if nlayers == 1
				y = T[w,:]
				ye = Te[w,:]
			else
				y = T[w,:,i]
				ye = Te[w,:,i]
			end
			if Tmax != nothing && Tmin != nothing
				y = y * (Tmax[w,i] - Tmin[w,i]) + Tmin[w,i]
				ye = ye * (Tmax[w,i] - Tmin[w,i]) + Tmin[w,i]
			end
			p[pc] = Gadfly.layer(x=xaxis, y=y, xintercept=xintercept, Gadfly.Geom.line, Gadfly.Theme(line_width=linewidth, default_color=colors[i]), Gadfly.Geom.vline)
			pc += 1
			p[pc] = Gadfly.layer(x=xaxis, y=ye, xintercept=xintercept, Gadfly.Geom.line, Gadfly.Theme(line_style=:dot, line_width=linewidth, default_color=colors[i]), Gadfly.Geom.vline)
			pc += 1
		end
		if wellnames != nothing
			tm = [Gadfly.Guide.title("$dimname $(wellnames[w]) $titletext")]
			if dimname != ""
				filename = "$(figuredir)/$(lowercase(dimname))_$(wellnames[w])$(append).png"
			else
				filename = "$(figuredir)/$(wellnames[w])$(append).png"
			end
		else
			tm = []
			if dimname != ""
				filename = "$(figuredir)/$(lowercase(dimname))$(append).png"
			else
				filename = "$(figuredir)/$(append[2:end]).png"
			end
		end
		yming = ymin
		ymaxg = ymax
		if ymin != nothing && length(ymin) > 1
			yming = ymin[w]
		end
		if ymax != nothing && length(ymax) > 1
			ymaxg = ymax[w]
		end
		f = Gadfly.plot(p..., tm..., Gadfly.Guide.XLabel(xtitle), Gadfly.Guide.YLabel(ytitle), gm..., Gadfly.Coord.Cartesian(xmin=xmin, xmax=xmax, ymin=yming, ymax=ymaxg))
		Gadfly.draw(Gadfly.PNG(filename, hsize, vsize, dpi=dpi), f)
		!quiet && (display(f); println())
	end
end