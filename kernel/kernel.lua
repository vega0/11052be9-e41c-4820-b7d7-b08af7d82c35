local fmt = string.fmt;

-- определение таблицы ядра.

_G. kernel = {}

function kernel.readToEof(file0)
  checkArg(1, file0, "string");

  local h, err = rom.open(file0);

  if( not h ) then
    error(fmt("Не получается открыть фаил (%s)", file0, err));
  end

  local buffer, data = '';

  repeat
    data, err = rom.read(h, math.huge);

    if( not data and err ) then
      error(fmt("Не удалось прочитать :%s: %s", file0, err));
    end
    buffer = buffer .. (data or "");
  until not data;

  rom.close(h);
  return buffer;
end

-- т.к. разработчики нам любезно нихуя не предоставили, имеем в наличии internal реализацию стандартных функций.

function loadfile(file)
  checkArg(1, file, "string");

  -- загружаем текстовый буфер

  jandle, reason = load(kernel.readToEof(file), "=" .. file);

  if( not jandle ) then
    error(fmt("Ошибка синтаксиса в файле :%s: %s", file, tostring(reason)));
  end

  return jandle; 
end

-- подгрузка чанка со специфичнным окружением.

function loadfile_with_speciefed_env(file, env)
  checkArg(1, file, "string");
  checkArg(2, env, "table");

  local chunk, err = load(kernel.readToEof(file), "=" .. file, "t", env);

  if( not chunk ) then error(fmt("Ошибка синтаксиса в файле :%s: %s", file, tostring(err))) end;
  return chunk;
end

function dofile(file)
  local result, reason = loadfile(file);

  if( not result ) then
    error("Ошибка в связи с загрузкой чанка: " .. reason);
  end

  result, reason = pcall(result);

  if( not result ) then
    error("Во время выполнения безопасного вызова произошла ошибка: " .. tostring(reason));
  end

  return result;
end

-- имплементация функции безопасного выполнения файла.

function dofile_safe(file0)
  local result, err = pcall(dofile, file0);
  if( not result ) then
    return string.fmt("%s: %s", file0, tostring(err));
  end
end

-- имплементация функции выполнения файла с указанным окружением

function dofile_with_speciefed_env(file0, env)
  local result, err = pcall(loadfile_with_speciefed_env(file0, env));

  if( not result ) then 
    error(fmt("Во время выполнения (%s) произошла ошибка: %a", file0, tostring(err)));
  end

  return result;
end

-- имплементация функции рекурсивной подгрузки директорий с возвратом отсчетности о выполнении.

function execute_directory( directory0 )
  checkArg(1, directory0, "string");

  if( not rom.exists(directory0) ) then
    error(string.fmt("Директория (%s) не существует!", directory0));
  end

  local list, info = rom.list(directory0), {};
  table.sort(list);
  for _, file in pairs(list) do
    local full_path = rom.concat(directory0, file);
    if(rom.isDirectory(full_path)) then
      for _, record in ipairs(execute_directory( full_path ) or {}) do
        table.insert(info, record);
      end
    else
      local result, err = pcall(dofile, full_path);

      if( not result ) then
        table.insert( info, string.fmt("%i. %s: %s", #info, full_path, tostring(err)) );
      end
    end
  end

  if(#list > 0) then
    return list;
  end
end