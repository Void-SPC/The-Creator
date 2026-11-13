--!nonstrict
-- Правила «Мафии» без Roblox API: раздача ролей, голосования, ночь, победа, чаты

local Rules = {}

Rules.MAX_PLAYERS = 13
Rules.MIN_PLAYERS = 4

Rules.ROLES = { mafia = true, doctor = true, sheriff = true, civilian = true }

Rules.LIMITS = {
	mafia = { 1, 6 },
	doctor = { 1, 3 },
	sheriff = { 1, 3 },
}

-- Автоматически: 1 доктор, 1 шериф, мафии примерно треть игроков (8 → 2, 12 → 4)
function Rules.autoCounts(n: number)
	local mafia = math.clamp(math.floor(n / 3), 1, 6)
	local doctor = if n >= 4 then 1 else 0
	local sheriff = if n >= 5 then 1 else 0
	return { mafia = mafia, doctor = doctor, sheriff = sheriff }
end

-- Проверка ручных настроек. Возвращает nil или текст проблемы
function Rules.checkCounts(n: number, c): string?
	for role, lim in Rules.LIMITS do
		local v = c[role]
		if type(v) ~= "number" or v ~= math.floor(v) or v < lim[1] or v > lim[2] then
			return role
		end
	end
	if c.mafia + c.doctor + c.sheriff > n then
		return "too_many_roles"
	end
	if c.mafia * 2 >= n then
		return "too_much_mafia"
	end
	return nil
end

-- Раздача ролей случайно. ids — список игроков (без ведущего), rand(a, b) — целое
function Rules.assign(ids: { any }, counts, rand: (number, number) -> number)
	local pool = table.clone(ids)
	-- перемешивание Фишера — Йейтса
	for i = #pool, 2, -1 do
		local j = rand(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local roles = {}
	local k = 1
	for _, role in { "mafia", "doctor", "sheriff" } do
		for _ = 1, counts[role] or 0 do
			if pool[k] ~= nil then
				roles[pool[k]] = role
				k += 1
			end
		end
	end
	for i = k, #pool do
		roles[pool[i]] = "civilian"
	end
	return roles
end

-- Дневное голосование: votes[voter] = цель или "skip". Изгоняется тот, у кого больше
-- всех голосов, если голосов за него больше, чем за «пропустить», и нет ничьей
function Rules.dayResult(votes, alive)
	local tally = {}
	local skip = 0
	for voter, target in votes do
		if alive[voter] then
			if target == "skip" then
				skip += 1
			elseif alive[target] then
				tally[target] = (tally[target] or 0) + 1
			end
		end
	end
	local best, bestN, tie = nil, 0, false
	for target, n in tally do
		if n > bestN then
			best, bestN, tie = target, n, false
		elseif n == bestN then
			tie = true
		end
	end
	if not best or tie or bestN <= skip then
		return nil, tally, skip
	end
	return best, tally, skip
end

-- Мафия должна прийти к общему решению: цель засчитывается, только если все живые
-- мафиози выбрали одного и того же
function Rules.mafiaTarget(votes, roles, alive)
	local target = nil
	local total, voted = 0, 0
	for id, role in roles do
		if role == "mafia" and alive[id] then
			total += 1
			local v = votes[id]
			if v ~= nil then
				voted += 1
				if target == nil then
					target = v
				elseif target ~= v then
					return nil, false
				end
			end
		end
	end
	if total == 0 or voted < total or not alive[target] then
		return nil, false
	end
	return target, true
end

-- Итог ночи: жертва мафии погибает, если её не вылечил ни один доктор
function Rules.nightResult(target, heals)
	if target == nil then
		return nil, false
	end
	for _, healed in heals do
		if healed == target then
			return nil, true
		end
	end
	return target, false
end

-- Победа: мафия, когда мирных (всех остальных) не больше мафии; город, когда мафии нет
function Rules.winner(roles, alive): string?
	local mafia, town = 0, 0
	for id, role in roles do
		if alive[id] then
			if role == "mafia" then
				mafia += 1
			else
				town += 1
			end
		end
	end
	if mafia == 0 then
		return "town"
	end
	if mafia >= town then
		return "mafia"
	end
	return nil
end

-- Чаты. who = { role = ..., alive = bool, host = bool }, phase = "lobby" | "day" | "vote" | "night" | ...
-- Возвращает, может ли игрок писать и видеть канал
function Rules.chat(channel: string, who, phase: string)
	if who.host then
		return true, true
	end
	local night = phase == "night"
	if channel == "general" then
		-- общий видят все; писать могут живые, и не ночью
		return who.alive and not night and phase ~= "reveal", true
	elseif channel == "mafia" then
		local isMafia = who.role == "mafia" and who.alive
		return isMafia, isMafia
	elseif channel == "ghost" then
		local ghost = not who.alive and who.role ~= nil
		return ghost, ghost
	end
	return false, false
end

return Rules
