extends SceneTree
## Deterministic original geometric artwork. No font or raster dependencies.
## Run: godot --headless --path godot --script ../steam/achievements/generate_icons.gd

const SIZE := 256
const DIGITS := {
	"0":["111","101","101","101","111"], "1":["010","110","010","010","111"],
	"2":["111","001","111","100","111"], "3":["111","001","111","001","111"],
	"4":["101","101","111","001","001"], "5":["111","100","111","001","111"],
	"6":["111","100","111","101","111"], "7":["111","001","010","010","010"],
	"8":["111","101","111","101","111"], "9":["111","101","111","001","111"]
}

var ink := "#10232e"
var muted := "#31555e"
var mint := "#83e7c1"
var dark_mint := "#3e9c91"
var pale := "#d9f9e5"
var amber := "#ffb577"
var violet := "#ba9ef2"

func rect(x: float, y: float, w: float, h: float, fill: String, radius: float = 0, stroke: String = "", thickness: float = 6) -> String:
	return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"%s/>' % [x,y,w,h,radius,fill,(' stroke="%s" stroke-width="%s"' % [stroke,thickness]) if not stroke.is_empty() else ""]

func path(d: String, fill: String, stroke: String = "", thickness: float = 6) -> String:
	return '<path d="%s" fill="%s"%s stroke-linecap="round" stroke-linejoin="round"/>' % [d,fill,(' stroke="%s" stroke-width="%s"' % [stroke,thickness]) if not stroke.is_empty() else ""]

func circle(x: float, y: float, r: float, fill: String, stroke: String = "", thickness: float = 6) -> String:
	return '<circle cx="%s" cy="%s" r="%s" fill="%s"%s/>' % [x,y,r,fill,(' stroke="%s" stroke-width="%s"' % [stroke,thickness]) if not stroke.is_empty() else ""]

func group(content: String, x: float, y: float, scale: float = 1.0) -> String:
	return '<g transform="translate(%s %s) scale(%s)">%s</g>' % [x,y,scale,content]

func number(value: String, x: float, y: float, pixel: float, color: String) -> String:
	var content := ""
	for digit in value:
		var rows: Array = DIGITS[digit]
		for row in range(5):
			for col in range(3):
				if rows[row][col] == "1": content += rect(x+col*pixel,y+row*pixel,pixel,pixel,color)
		x += pixel*4
	return content

func cube(x: float, y: float, size: float, color: String = "") -> String:
	if color.is_empty(): color = mint
	var s := size
	var left := "M%s %s l%s %s v%s l%s %s Z" % [x,y+s*.25,s*.5,s*.25,s*.55,-s*.5,-s*.25]
	var right := "M%s %s l%s %s v%s l%s %s Z" % [x+s*.5,y+s*.5,s*.5,-s*.25,s*.55,-s*.5,s*.25]
	var top := "M%s %s l%s %s l%s %s l%s %s Z" % [x,y+s*.25,s*.5,-s*.25,s*.5,s*.25,-s*.5,s*.25]
	return path(left,dark_mint,ink,4)+path(right,muted,ink,4)+path(top,color,ink,4)

func tower(x: float, y: float, width: float, height: float, color: String = "") -> String:
	if color.is_empty(): color = mint
	return rect(x,y+width*.25,width,height,dark_mint,3,ink,5)+rect(x+width*.62,y+width*.25,width*.38,height,muted)+cube(x-4,y,width+8,color)

func check(x: float, y: float, scale: float = 1.0, color: String = "") -> String:
	if color.is_empty(): color = pale
	return group(path("M0 24 L20 44 L62 0","none",ink,17)+path("M0 24 L20 44 L62 0","none",color,10),x,y,scale)

func plus(x: float, y: float, size: float, color: String) -> String:
	return rect(x+size*.35,y,size*.3,size,color,2)+rect(x,y+size*.35,size,size*.3,color,2)

func arrow(x: float, y: float, scale: float = 1.0) -> String:
	return group(path("M24 0 L50 28 H36 V68 H12 V28 H-2 Z",amber,ink,5),x,y,scale)

func shield(x: float, y: float, scale: float = 1.0) -> String:
	return group(path("M0 0 L60 -14 L120 0 V62 Q116 108 60 140 Q4 108 0 62 Z",dark_mint,ink,7)+path("M60 -5 L111 6 V61 Q107 99 60 129 Z",muted)+path("M12 10 L60 0 L108 10","none",mint,7),x,y,scale)

func grid(x: float, y: float, cell: float, selected: Array = [], digits: bool = false) -> String:
	var content := rect(x-5,y-5,cell*3+10,cell*3+10,ink,8,muted,5)
	for n in range(9):
		var xx := x+(n%3)*cell
		var yy := y+floori(n/3.0)*cell
		var fill := mint if selected.has(n) else muted
		content += rect(xx+3,yy+3,cell-6,cell-6,fill,2)
		if digits: content += number(str(n+1),xx+cell*.26,yy+cell*.13,cell*.15,ink if selected.has(n) else pale)
	return content

func module_tile(x: float, y: float, size: float, kind: int = 0, fill: String = "") -> String:
	if fill.is_empty(): fill = mint
	var content := rect(x,y,size,size,fill,8,ink,6)
	content += rect(x+size*.13,y+size*.13,size*.74,size*.74,ink,3)
	if kind == 0:
		content += path("M%s %s L%s %s L%s %s L%s %s L%s %s L%s %s Z" % [x+size*.54,y+size*.2,x+size*.3,y+size*.55,x+size*.48,y+size*.55,x+size*.4,y+size*.83,x+size*.73,y+size*.43,x+size*.55,y+size*.43],amber)
	elif kind == 1:
		content += circle(x+size*.5,y+size*.5,size*.2,pale)
		content += path("M%s %s V%s M%s %s H%s" % [x+size*.5,y+size*.22,y+size*.78,x+size*.22,y+size*.5,x+size*.78],"none",pale,5)
	else:
		content += path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % [x+size*.5,y+size*.2,x+size*.1,y+size*.66,x+size*.5,y+size*.8,x+size*.9,y+size*.66,x+size*.5,y+size*.2],violet)
	return content

func crown(x: float, y: float, scale: float = 1.0) -> String:
	return group(path("M0 0 L22 16 L40 -12 L58 16 L80 0 L70 40 H10 Z",amber,ink,6),x,y,scale)

func motif(id: String) -> String:
	match id:
		"SD_FIRST_PLANT":
			return cube(65,118,126)+path("M128 132 V75 M128 105 Q86 109 88 74 Q119 74 128 105 M128 89 Q171 90 173 57 Q139 57 128 89","none",mint,9)+number("1",111,152,9,amber)
		"SD_FIRST_UNIT":
			return grid(50,47,52,[3,4,5])+path("M38 126 H218","none",pale,5)+circle(218,126,8,amber)
		"SD_FIRST_UPGRADE":
			return tower(56,100,72,89)+arrow(154,47,1.1)
		"SD_FIRST_MODULE":
			return tower(53,113,88,83)+module_tile(123,51,83)+plus(151,152,44,amber)
		"SD_FIRST_CHEST":
			return path("M45 119 H211 V188 L128 214 L45 188 Z",dark_mint,ink,7)+path("M128 144 L211 119 V188 L128 214 Z",muted)+path("M45 119 V88 Q46 63 72 63 H184 Q209 63 211 88 V119 L128 144 Z",mint,ink,7)+path("M128 144 V214 M72 70 V126 M184 70 V126","none",ink,6)+rect(110,126,36,38,amber,4,ink,5)+rect(122,136,12,17,ink,1)
		"SD_FIRST_BOOST":
			return circle(128,128,83,ink,muted,9)+path("M142 42 L72 143 H117 L104 214 L188 106 H142 L156 42 Z",amber,ink,7)+path("M44 73 L58 82 M199 173 L214 183 M64 199 L75 187","none",mint,7)
		"SD_FIRST_CLEAR":
			return shield(62,62,1.1)+check(96,119,1.0)
		"SD_FIRST_BOSS":
			return crown(75,50,1.3)+path("M61 112 L84 88 H173 L196 112 V171 L170 200 H86 L61 171 Z",dark_mint,ink,7)+path("M128 88 H173 L196 112 V171 L170 200 H128 Z",muted)+path("M82 130 L111 143 M145 143 L174 130","none",amber,11)+rect(104,173,48,9,pale,2)+path("M39 160 L54 153 M204 153 L219 160","none",mint,6)
		"SD_ROUND_10":
			return path("M61 208 V49 H204 L181 89 L204 130 H63",mint,ink,8)+path("M62 135 V208","none",amber,12)+number("10",89,62,9,ink)+path("M43 214 H92","none",pale,8)
		"SD_ROUND_25":
			return circle(128,128,84,ink,muted,13)+path("M128 44 A84 84 0 1 1 44 128","none",mint,13)+path("M38 133 L44 112 L62 130",amber)+number("25",83,102,13,amber)
		"SD_CAMPAIGN_CLEAR":
			return path("M63 64 H42 V95 Q42 138 85 138 M193 64 H214 V95 Q214 138 171 138","none",amber,12)+path("M66 49 H190 V101 Q188 151 141 164 V190 H169 V210 H87 V190 H115 V164 Q68 151 66 101 Z",mint,ink,7)+path("M129 49 H190 V101 Q188 151 141 164 V190 H129 Z",dark_mint)+number("50",88,77,11,ink)
		"SD_LOCKED_CLEAR":
			return path("M80 115 V79 Q80 37 128 37 Q176 37 176 79 V115","none",mint,17)+rect(57,105,142,105,dark_mint,12,ink,7)+rect(129,109,65,96,muted,7)+number("50",85,132,12,amber)
		"SD_FIRST_FAMILY":
			return path("M55 192 H201 M128 157 V195","none",amber,7)+tower(40,126,45,52)+tower(106,104,45,74)+tower(172,126,45,52)+arrow(109,43,.6)
		"SD_FAMILY_FIVE":
			return tower(41,121,44,70)+tower(107,99,44,92)+tower(173,121,44,70)+circle(129,69,33,ink,amber,6)+number("5",115,47,9,amber)
		"SD_TOWER_FIVE":
			return tower(88,46,80,139)+path("M79 210 H177","none",mint,8)+number("5",106,112,14,amber)
		"SD_FIVE_SOCKETS":
			var s := tower(94,44,68,143)
			for n in range(5): s += rect(112,95+n*21,32,14,amber,2,ink,3)
			return s+path("M58 80 V194 H81 M197 80 V194 H176","none",mint,7)
		"SD_STACK_MODULES":
			return module_tile(56,104,111,0,dark_mint)+module_tile(91,52,111)+path("M48 92 V62 H78","none",amber,7)+path("M211 170 V199 H182","none",amber,7)
		"SD_THREE_EFFECTS":
			return path("M82 166 L128 80 L174 166 Z","none",muted,10)+module_tile(91,40,74,0)+module_tile(42,137,74,1,dark_mint)+module_tile(141,137,74,2,amber)
		"SD_TARGET_LINEUP":
			var s := path("M63 158 L128 77 L193 158","none",muted,9)
			for p in [Vector2(61,166),Vector2(128,79),Vector2(195,166)]:
				s += circle(p.x,p.y,30,ink,mint,7)+circle(p.x,p.y,13,ink,amber,5)+circle(p.x,p.y,4,pale)
			return s+path("M128 32 V49 M16 166 H31 M225 166 H240","none",pale,5)
		"SD_NINE_FAMILIES":
			return grid(46,46,55,[0,1,2,3,4,5,6,7,8],true)
		"SD_HARD_GRID":
			return grid(43,69,48,[0,3,4,7,8])+path("M185 33 L221 69 L185 105 L149 69 Z",amber,ink,7)+path("M185 50 V75 M185 86 V87","none",ink,7)
		"SD_NO_HINT_GRID":
			return grid(39,82,43,[0,1,2,3,4,5,6,7,8])+path("M153 114 Q125 90 139 63 Q152 39 176 43 Q207 46 207 77 Q207 98 188 113 V132 H153 Z",amber,ink,7)+path("M154 144 H187 M160 155 H181 M170 114 V86 L158 72 M170 86 L184 72","none",pale,6)+path("M130 37 L120 26 M216 40 L226 29","none",mint,6)
		"SD_BOSS_WAVE_CLEAN":
			return shield(62,81,1.1)+crown(84,43,1.1)+check(96,138,.95)
		"SD_CORRUPT_CLEAR":
			return path("M46 54 L93 70 L109 45 L142 69 L190 51 L179 100 L211 130 L180 157 L196 203 L143 184 L127 211 L98 184 L48 201 L65 153 L39 127 L70 96 Z",violet,ink,7)+number("3",91,78,19,ink)+check(157,173,.65,amber)
		"SD_UNFINISHED_CLEAR":
			return grid(43,47,51,[0,1,3,4,6])+check(142,171,1.05,amber)
		"SD_CLEAN_CAMPAIGN":
			return path("M75 199 Q26 155 59 89 M181 199 Q230 155 197 89","none",dark_mint,11)+path("M60 172 L39 166 M56 144 L35 134 M61 115 L43 101 M196 172 L217 166 M200 144 L221 134 M195 115 L213 101","none",mint,10)+grid(79,52,33,[0,1,2,3,4,5,6,7,8])+check(96,165,1.05,amber)
	return ""

func make_svg(id: String, locked: bool) -> String:
	ink = "#15212a" if locked else "#10232e"
	muted = "#3e4b55" if locked else "#31555e"
	mint = "#8a98a0" if locked else "#83e7c1"
	dark_mint = "#5a6871" if locked else "#3e9c91"
	pale = "#b3bec3" if locked else "#d9f9e5"
	amber = "#99a1aa" if locked else "#ffb577"
	violet = "#788591" if locked else "#ba9ef2"
	var art := rect(0,0,256,256,"#08151e")+rect(9,9,238,238,ink,25,muted,4)
	art += path("M26 72 V36 Q26 26 36 26 H72 M184 230 H220 Q230 230 230 220 V184","none",muted,4)
	art += motif(id)
	if locked: art += circle(224,224,15,ink,muted,2)+rect(218,222,12,9,pale,1)+path("M220 222 V217 Q224 211 228 217 V222","none",pale,2)
	return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">%s</svg>\n' % art

func _initialize() -> void:
	var project_root := ProjectSettings.globalize_path("res://")
	var repo_root := project_root.trim_suffix("/").get_base_dir()
	var source_path := project_root.path_join("assets/achievements")
	var export_path := repo_root.path_join("steam/achievements/icons")
	DirAccess.make_dir_recursive_absolute(source_path)
	DirAccess.make_dir_recursive_absolute(export_path)
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(project_root.path_join("data/achievements.json")))
	if not catalog is Array or catalog.size() != 26:
		push_error("Expected 26 catalog entries")
		quit(1)
		return
	var sheet := Image.create(7*256,8*256,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("08151e"))
	var records: Array = []
	var icon_hashes: Dictionary = {}
	for index in range(catalog.size()):
		var entry: Dictionary = catalog[index]
		for locked in [false,true]:
			var svg := make_svg(str(entry.id),locked)
			if motif(str(entry.id)).is_empty():
				push_error("Missing icon: "+str(entry.id)); quit(1); return
			var name: String = str(entry.icon)+("_locked" if locked else "")
			var source := source_path.path_join(name+".svg")
			var out_file := FileAccess.open(source,FileAccess.WRITE)
			if out_file == null: push_error("Cannot write icon source"); quit(1); return
			out_file.store_string(svg)
			out_file.close()
			var image := Image.new()
			if image.load_svg_from_string(svg) != OK or image.get_width() != SIZE or image.get_height() != SIZE:
				push_error("SVG render failed: "+name); quit(1); return
			var png := export_path.path_join(str(entry.id)+("_UNACHIEVED" if locked else "_ACHIEVED")+".png")
			if image.save_png(png) != OK: push_error("PNG save failed"); quit(1); return
			var png_hash := FileAccess.get_sha256(png)
			if icon_hashes.has(png_hash): push_error("Duplicate icon pixels: "+name); quit(1); return
			icon_hashes[png_hash] = name
			var sheet_index: int = index+(28 if locked else 0)
			sheet.blit_rect(image,Rect2i(0,0,SIZE,SIZE),Vector2i((sheet_index%7)*SIZE,(sheet_index/7)*SIZE))
			records.append({"id":entry.id,"locked":locked,"source":"godot/assets/achievements/"+name+".svg","png":"steam/achievements/icons/"+png.get_file(),"width":SIZE,"height":SIZE,"sha256":png_hash})
	sheet.save_png(repo_root.path_join("steam/achievements/contact-sheet.png"))
	sheet.resize(7*64,8*64,Image.INTERPOLATE_LANCZOS)
	sheet.save_png(repo_root.path_join("steam/achievements/contact-sheet-64.png"))
	var manifest := FileAccess.open(repo_root.path_join("steam/achievements/icon-manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"style":"Original geometric voxel artwork; no fonts or external images","renderer":Engine.get_version_info().string,"icons":records},"\t")+"\n")
	manifest.close()
	print("ACHIEVEMENT_ICONS_PASS count=52 size=256x256")
	quit()
