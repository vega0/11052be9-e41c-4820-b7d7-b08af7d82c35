print("Тест строка!");

-- выводим в подтверждение того что окружение поменялось

--print(_G, _G == nil); -- производит ошибку arg #1 is nil for table.concat function.                                                                                                                        fixme(!)
print(tostring(_G), tostring(_G == nil)); -- временное решение.

-- удаляем все директории начинающиеся на префикс this.filename();

print("Название этого файла", this.filename());

for _, path in pairs(rom.list("/")) do
	if(string.sub(path, 1, string.length(this.filename())) == this.filename()) then

		print(string.fmt("Фаил %s попадает под условие", path))

		if(rom.isDirectory(path)) then	
			print("    и удалится", path);
		end

		--if rom.isDirectory(path) and not rom.remove(path) then
		--	error(string.fmt("Невозможно удалить: %s", path));
		--end
	end
end

-- создаем директорию со случайным именем

local tmp_directory = string.fmt("%s_%x", this.filename(), math.random(0, 0xffffffff));

print(tmp_directory);

--if not rom.makeDirectory(tmp_directory) then
--	error("Не получилось создать директорию!")
--end

-- тестим ask

while true do
	ask("Вам хорошо?", {good = "Yes", "No"}, function()
		print("Мне тоже!")
	end)

	ask("Сколько будет 5+5?", {good = "10", "13", "25"}, function()
		print("Верно!")
	end)

	if ask("Выйти из цикла?", {good = "Yes", "No"}, function()
		print("Ура!")
	end) == true then
		break;
	end

end

-- тестим юиникод

do
	local function print_with_length(str)
		print(string.fmt("normal '%s' (len '%s') дважды объедененный '%s'", str, string.length(str), str .. str));
	end
	
	print_with_length("Its unicode");
	print_with_length("Это юникод!");

	local function print_with_utf8_length(str)
		print(string.fmt("utf8 '%s' (len '%s') дважды объедененный '%s'", str, unicode.length(str), str .. str));
	end

	print_with_utf8_length("Это юникод!");
	print_with_utf8_length("Its unicode");

	-- выводим все символы юникода 

	ask("Вывести все символы юникода?", {good = "Yes", "No"}, function()
		for i = 0, 0xffff do
			write(unicode.char(i));
		end
	end)
end

-- имплементация функуци генерирования рандомного мусора

do

	print("Временная директория", tmp_directory);

	local code = [[
		-- this is random junk which number is %i
	]]

	local function generate_random_junk(directory)
		local hom_much = math.random(1, 25);

		for i = 0, how_much do
			
		end
	end

end
