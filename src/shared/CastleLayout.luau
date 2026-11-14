--!nonstrict
-- План замка без Roblox API: сетка 7 × 7 клеток по 32 studs на каждом ярусе,
-- какие клетки заняты какими комнатами, где коридоры, лестницы и двери.
-- Сборщик строит стены по этому плану, а тесты проверяют, что в каждую комнату можно дойти

local Layout = {}

Layout.C = 32 -- размер клетки
Layout.N = 7 -- клеток по стороне
Layout.H = 18 -- высота этажа
Layout.HALF = Layout.C * Layout.N / 2 -- 112: край главного здания
-- верх пола каждого яруса
Layout.LEVELS = { U = -18, G = 0, F1 = 18, F2 = 36 }
Layout.ORDER = { "U", "G", "F1", "F2" }

-- центр клетки
function Layout.center(i: number, j: number): (number, number)
	return (i - 3) * Layout.C, (j - 3) * Layout.C
end

-- прямоугольные комнаты: { kind, i0, i1, j0, j1, tall = двойная высота, special = строится отдельно }
local PLAN = {
	U = {
		{ "library", 2, 6, 0, 4, special = true },
		{ "storeroom", 0, 1, 0, 1 },
		{ "prison_guard", 0, 0, 2, 2, stairsFrom = "G" },
		{ "guardroom", 1, 1, 2, 2 },
		{ "prison", 0, 1, 3, 6, special = true },
		{ "cellar", 2, 6, 5, 5 },
		{ "storage", 2, 2, 6, 6 },
		{ "sewer", 3, 6, 6, 6, special = true },
	},
	G = {
		{ "grand_hall", 2, 4, 0, 1, tall = true },
		{ "throne", 2, 4, 4, 6, tall = true, special = true },
		{ "kitchen", 0, 1, 0, 1 },
		{ "dining", 0, 1, 4, 5 },
		{ "servants", 0, 1, 6, 6 },
		{ "stairs_down", 0, 0, 2, 2, down = "prison" },
		{ "stairs", 1, 1, 2, 2 },
		{ "shop", 2, 2, 2, 2 },
		{ "casino", 4, 4, 2, 2 },
		{ "stairs", 5, 5, 2, 2 },
		{ "stairs_down", 6, 6, 2, 2, down = "library" },
		{ "barracks", 5, 6, 0, 1 },
		{ "training", 5, 6, 4, 5 },
		{ "chapel", 5, 6, 6, 6 },
	},
	F1 = {
		{ "bedroom", 0, 0, 0, 0 },
		{ "bedroom", 1, 1, 0, 0 },
		{ "study", 0, 0, 1, 1 },
		{ "bedroom", 1, 1, 1, 1 },
		{ "sitting", 0, 0, 2, 2 },
		{ "stairs", 1, 1, 2, 2 },
		{ "reading", 2, 2, 2, 2 },
		{ "trophy", 4, 4, 2, 2 },
		{ "stairs", 5, 5, 2, 2 },
		{ "sitting", 6, 6, 2, 2 },
		{ "music", 0, 1, 4, 5 },
		{ "bath", 0, 0, 6, 6 },
		{ "bedroom", 1, 1, 6, 6 },
		{ "bedroom", 5, 5, 0, 0 },
		{ "bedroom", 6, 6, 0, 0 },
		{ "gallery", 5, 6, 1, 1 },
		{ "lounge", 5, 6, 4, 4 },
		{ "nursery", 5, 5, 5, 5 },
		{ "wardrobe", 6, 6, 5, 5 },
		{ "guest_suite", 5, 6, 6, 6 },
	},
	F2 = {
		{ "observatory", 0, 0, 0, 0 },
		{ "treasury", 1, 2, 0, 1 },
		{ "council", 4, 5, 0, 1 },
		{ "map_room", 6, 6, 0, 0 },
		{ "study", 0, 0, 1, 1 },
		{ "trophy", 6, 6, 1, 1 },
		{ "bedroom", 0, 0, 2, 2 },
		{ "landing", 1, 1, 2, 2 },
		{ "bedroom", 2, 2, 2, 2 },
		{ "bedroom", 4, 4, 2, 2 },
		{ "landing", 5, 5, 2, 2 },
		{ "sitting", 6, 6, 2, 2 },
		{ "bedroom", 0, 0, 4, 4 },
		{ "royal_dining", 1, 2, 4, 4 },
		{ "lounge", 4, 5, 4, 4 },
		{ "bath", 6, 6, 4, 4 },
		{ "wardrobe", 0, 0, 5, 5 },
		{ "chapel_small", 0, 0, 6, 6 },
		{ "queen", 1, 2, 5, 6 },
		{ "king", 4, 5, 5, 6 },
		{ "bath", 6, 6, 5, 5 },
		{ "study", 6, 6, 6, 6 },
	},
}

-- клетки коридоров на каждом ярусе
local HALLS = {
	U = {},
	G = { { 3, 2 } },
	F1 = { { 3, 2 } },
	F2 = { { 3, 0 }, { 3, 1 }, { 3, 2 }, { 3, 4 }, { 3, 5 }, { 3, 6 } },
}
-- ряд j = 3 — коридор на всех надземных ярусах
for _, lv in { "G", "F1", "F2" } do
	for i = 0, 6 do
		table.insert(HALLS[lv], { i, 3 })
	end
end
-- клетки над залами двойной высоты пустые
local VOID = { F1 = {} }
for i = 2, 4 do
	for _, j in { 0, 1, 4, 5, 6 } do
		table.insert(VOID.F1, { i, j })
	end
end

-- Строит план уровня: grid[i][j] = id комнаты (или "void"), rooms[id] = комната, doors = список
function Layout.build(level: string)
	local grid = {}
	for i = 0, 6 do
		grid[i] = {}
	end
	local rooms = {}
	local function add(room)
		room.id = #rooms + 1
		room.level = level
		rooms[room.id] = room
		for i = room.i0, room.i1 do
			for j = room.j0, room.j1 do
				assert(grid[i][j] == nil, string.format("%s: клетка %d,%d занята дважды", level, i, j))
				grid[i][j] = room.id
			end
		end
		return room
	end
	for _, r in PLAN[level] do
		add({ kind = r[1], i0 = r[2], i1 = r[3], j0 = r[4], j1 = r[5], tall = r.tall, special = r.special, down = r.down })
	end
	local hall = nil
	for _, c in HALLS[level] do
		if not hall then
			hall = add({ kind = "hall", i0 = c[1], i1 = c[1], j0 = c[2], j1 = c[2], cells = {} })
			table.insert(hall.cells, c)
		else
			grid[c[1]][c[2]] = hall.id
			table.insert(hall.cells, c)
		end
	end
	for _, c in (VOID[level] or {}) do
		assert(grid[c[1]][c[2]] == nil, "void over room")
		grid[c[1]][c[2]] = "void"
	end
	for i = 0, 6 do
		for j = 0, 6 do
			assert(grid[i][j] ~= nil, string.format("%s: пустая клетка %d,%d", level, i, j))
		end
	end

	-- соседство: пары клеток через общую стену
	local edges = {} -- [a.."-"..b] = список { i, j, side } (сторона +x или +z от клетки i,j)
	local function key(a, b)
		return if a < b then a .. "-" .. b else b .. "-" .. a
	end
	for i = 0, 6 do
		for j = 0, 6 do
			for _, d in { { 1, 0, "x" }, { 0, 1, "z" } } do
				local ni, nj = i + d[1], j + d[2]
				if ni <= 6 and nj <= 6 then
					local a, b = grid[i][j], grid[ni][nj]
					if a ~= b and type(a) == "number" and type(b) == "number" then
						local k = key(a, b)
						edges[k] = edges[k] or { a = math.min(a, b), b = math.max(a, b), list = {} }
						table.insert(edges[k].list, { i = i, j = j, axis = d[3] })
					end
				end
			end
		end
	end

	-- лестничные клетки и особые зоны соединяются только с коридором
	local function onlyHall(room)
		return room.kind == "stairs" or room.kind == "stairs_down" or room.kind == "landing" or room.special or room.kind == "prison_guard"
	end
	local doors = {}
	local connected = {}
	local function addDoor(e, wide)
		local mid = e.list[math.ceil(#e.list / 2)]
		table.insert(doors, { a = e.a, b = e.b, i = mid.i, j = mid.j, axis = mid.axis, wide = wide })
		connected[e.a] = true
		connected[e.b] = true
	end
	local function allowed(ra, rb)
		local function pair(x, y)
			return (ra.kind == x and rb.kind == y) or (ra.kind == y and rb.kind == x)
		end
		-- библиотека открывается в винный погреб с верхней галереи
		if ra.kind == "library" or rb.kind == "library" then
			return pair("library", "cellar")
		end
		-- в тюрьму и в тайный ход обычных дверей нет
		if ra.kind == "sewer" or rb.kind == "sewer" or ra.kind == "prison" or rb.kind == "prison" then
			return false
		end
		if pair("prison_guard", "guardroom") then
			return true
		end
		if onlyHall(ra) and rb.kind ~= "hall" then
			return false
		end
		if onlyHall(rb) and ra.kind ~= "hall" then
			return false
		end
		return true
	end
	-- 1) все комнаты, касающиеся коридора, получают дверь в коридор
	local sorted = {}
	for _, e in edges do
		table.insert(sorted, e)
	end
	table.sort(sorted, function(x, y)
		if x.a ~= y.a then
			return x.a < y.a
		end
		return x.b < y.b
	end)
	for _, e in sorted do
		local ra, rb = rooms[e.a], rooms[e.b]
		if (ra.kind == "hall" or rb.kind == "hall") and allowed(ra, rb) then
			addDoor(e, (ra.tall or rb.tall or ra.kind == "throne" or rb.kind == "throne") == true)
		end
	end
	-- 2) остальные подключаются к уже связанным соседям (обход в ширину)
	if not hall then
		-- подземный ярус: начало у лестницы из главного зала
		for _, r in rooms do
			if r.kind == "prison_guard" or r.kind == "library" then
				connected[r.id] = true
			end
		end
	end
	local changed = true
	while changed do
		changed = false
		for _, e in sorted do
			local ra, rb = rooms[e.a], rooms[e.b]
			if connected[e.a] ~= connected[e.b] and allowed(ra, rb) then
				addDoor(e, false)
				changed = true
			end
		end
	end
	-- 3) немного дополнительных дверей между жилыми комнатами, чтобы было как в старом доме
	local extra = 0
	for _, e in sorted do
		local ra, rb = rooms[e.a], rooms[e.b]
		local has = false
		for _, d in doors do
			if (d.a == e.a and d.b == e.b) then
				has = true
			end
		end
		if not has and allowed(ra, rb) and ra.kind ~= "hall" and rb.kind ~= "hall" and (e.a + e.b) % 3 == 0 and extra < 4 then
			addDoor(e, false)
			extra += 1
		end
	end
	return { level = level, grid = grid, rooms = rooms, doors = doors, connected = connected }
end

-- Проверка связности (для тестов): из какой комнаты в какую можно пройти
function Layout.reachable(plan, startId)
	local adj = {}
	for _, d in plan.doors do
		adj[d.a] = adj[d.a] or {}
		adj[d.b] = adj[d.b] or {}
		table.insert(adj[d.a], d.b)
		table.insert(adj[d.b], d.a)
	end
	local seen = { [startId] = true }
	local queue = { startId }
	while #queue > 0 do
		local id = table.remove(queue, 1)
		for _, n in adj[id] or {} do
			if not seen[n] then
				seen[n] = true
				table.insert(queue, n)
			end
		end
	end
	return seen
end

return Layout
