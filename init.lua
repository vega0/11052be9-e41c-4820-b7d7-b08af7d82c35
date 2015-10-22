-- определяем свойства и конфигурации

_G.OS_VERSION = 0.1;
_G.OS_NAME = "Операционная система";
_G.IN_INIT = true;
_G.AsksEnabled = true;

-- ищем дисплей с клавиатурой

local screen = component.proxy(component.list("screen")());

for screen_address in component.list("screen") do
  if( #component.invoke(screen_address, "getKeyboards") > 0) then
      screen = component.proxy(screen_address);
  end
end

if( not screen or screen == nil) then
  error("Screen not found!")
end

-- ищем графику

local gpu = component.proxy(component.list("gpu", true)());

if( not gpu or gpu == nil ) then
  error("Gpu not found!")
end

-- присваем графическому адаптеру адресс дисплея с которым мы работаем.

if(gpu.bind(screen.address) == false) then
  error(string.format("Cannot bind Screen (%s) to GPU", string.upper(screen.address)));
end

--[[
  gpu.getAddress() - возвращает адресс дисплея к которому привязан. (!) Видеокарта может работать одновременно только с одним дисплеем.
]]

-- получаем разрешение дисплея

local resolution = { w = 0, h = 0};

do
  local w, h = gpu.getResolution();

  resolution.w = w;
  resolution.h = h;
end

-- добавляем функцию в table для конкатернации таблиц с опущенным клюем (!) порядок параметров не сохраняется

function table.concat_raw( tbl, ... )
  local stack = {};
  for k, v in ipairs( tbl ) do
    table.insert(stack, v);
  end
  return table.concat(stack, ...);
end

-- устанавливаем разрешение дисплея

gpu.setResolution(gpu.getResolution());

local function display_clear()
  -- устанавливаем белый цвет тексту
  gpu.setForeground(0xffffffff);
  -- устанавливаем серый цвет фону
  gpu.setBackground(0xbfbdbd);
  -- заливаем область дисплея
  gpu.fill(1,1, resolution.w, resolution.h, string.char(32));
end

-- устанавливаем некоторые алиасы

string.length = string.len;
string.fmt = string.format;

unicode.length = unicode.len;

-- очищаем дисплей

display_clear();

-- имплементация временных функцйи

local write, backspace, print, newline,
  log, input, ask

do
  local cursor = {x = 1, y = 1};

  local function scroll_down_if_its_possible() 
    if(cursor.y > resolution.h) then -- сдвиг происходит тогда, когда каретка Y вышла за область разрешения h
      local diff = resolution.h - cursor.y;
      gpu.copy(1, 1, resolution.w, resolution.h, 0, diff); -- сдвигаем весь буфер экрана.
      gpu.fill(1, resolution.h + diff + 1, resolution.w, diff*-1, string.char(32)); -- очищаем мусор
      cursor.y = cursor.y + diff;
    end
  end

  function write( ... )
    local arguments = {...};

    for k, v in ipairs(arguments) do
      arguments[k] = tostring(v) -- приводим к текстовой форме любую переменную (!) важно знать что при такой форме итерирования пропадают именные элементы таблицы (т.е. {a = "a"} = nothing)
    end

    local complete_string = table.concat(arguments, ", ");

    -- проверяем границы каретки

    if(cursor.x > resolution.w) then
      cursor.x = cursor.x - resolution.w;
      cursor.y = cursor.y + 1;
    end

    scroll_down_if_its_possible();

    gpu.set(cursor.x, cursor.y, complete_string);
    cursor.x = cursor.x + unicode.length(complete_string);
  end

  function backspace()
    cursor.x = cursor.x - 1;

    if cursor.x < 1 then
      cursor.x = resolution.w;
      cursor.y = math.max(1, cursor.y - 1);
    end

    gpu.set(cursor.x, cursor.y, string.char(32));
  end

  function print( ... )
      write( ... )
      cursor.y = cursor.y + 1;
      cursor.x = 1;
  end

  function newline()
    cursor.x = 1;
    cursor.y = cursor.y + 1;
    scroll_down_if_its_possible();
  end

  do
    local line_counter = 0;
    function log( msg, data, state )
      if( state == "lbl" ) then
        print(string.fmt("%i. [[%s]]", line_counter, string.upper(msg)));
      else
        print(string.fmt("%i. %s: %s", line_counter, msg, data))
      end

      line_counter = line_counter + 1;
    end
  end

  -- имплементация считывания строки

  function input(length)
    if(length) then
      checkArg(1, length, "number");
    else length = 12 end

    local str = '';

    while (length or 12) ~= 0 do
      local event, _, char, code = computer.pullSignal();

      if( event == "key_down" and char ~= 0 ) then
        if(char == 13) then break;
        elseif( char == 8 ) then  
          str = unicode.sub(str, 1, unicode.length(str) - 1);
          if length ~= 0 then backspace() end -- очищаем символ с буфера.
          length = length + 1;
        else 
          local char = unicode.char( char );
          str = str .. char;
          write(char);
          length = length - 1;
        end
      end
    end

    newline();

    return str;
  end

  -- функция оперироания с пользователем

  function ask(question, variants, good, bad)
    if(not AsksEnabled) then return true; end

    checkArg(1, question, "string");
    checkArg(2, variants, "table");
    if(good) then checkArg(3, good, "function"); end
    if(bad) then checkArg(4, bad, "function"); end

    if( not variants.good ) then
      error("Укажите ключ в таблице variant с пометкой good!");
    end
    table.insert(variants, variants.good); -- предусматриваем проглатывание значений с именным ключем функцией table.concat;                                                                fixme(!) добавить функцию конкатернации значений таблицы игнорируя ключи.
    write(string.fmt("%s? (%s): ", question, table.concat(variants, "/")));

    local input = input();

    if(string.lower(variants.good) == string.lower(input)) then
      if(good) then good(); end
      return true;
    end

    if(bad) then bad((function() for _, str in pairs(variants) 
        do if(string.find(str, input)) then return str end end end)()); end 
    return false;
  end
end

-- выводим на экран приветствие, говорим о том что все хорошо;

print("Доброго времени суток (!)");

-- выводим список компонентов

for address, name in component.list() do
  log(address, name);
end

-- выводим значения глобальной таблицы

log("вывод глобальной таблицы на экран", nil, "lbl");

for k, v in pairs( _G ) do
  log(k, tostring(v));
end

-- определение eeprom

local eeprom = component.proxy(component.list("eeprom")())

--[[
  eeprom.getData() - возращает адрес файловой системы с которой произошла загрузка.
]]

-- временная имплементация rom

local rom = component.proxy(eeprom.getData());

if( not rom or rom == nil ) then
  error("ROM initialization failed");
end

-- запускаем testsuit.lua

ask("Хотите ли вы произвести тестирование?", {good = "Yes", "No"}, function()
  do
    log("Начало загрузки файла", "testsuit.lua");

    local jandle, reason = rom.open("testsuit.lua"); -- открываем фаил

    if( not jandle ) then
      error("Coul'd not open testsuit.lua: " .. reason);
    end

    local buffer, counter = '', 0;

    repeat
      local data, reason = rom.read(jandle, math.huge); -- читаем линию из файла

      if ( not data and reason ) then
        error("coul'd not read the handle:" .. reason);
      else
        counter = counter + 1;
      end

      buffer = buffer .. (data or "");
    until not data;

    rom.close(jandle);

    log("Текстовый фаил загружен в буфер", 
      string.fmt("длинна (%i), подходов к считыванию (%i)", string.len(buffer), counter));

    -- загружаем текстовый буфер

    local chunk;
    chunk, reason = load(buffer, nil, 't', 
      { 
        print = print, write = write, 
        log = log, rom = rom, tostring = tostring, 
        pairs = pairs, math = math, 
        string = string, this = {filename = function() return "testsuit" end},
        unicode = unicode, ask = ask
      } -- определяем окружение
    );

    if(not chunk) then
      error("Chunk error: " .. reason);
    end

    -- запускаем чанк с помощью безопасного вызова (protected call)

    local status, err = pcall(chunk);

    if( not status ) then
      error("Chunk raised error: " .. tostring(err));
    end
  end
end )

-- т.к. разработчики нам любезно нихуя не предоставили, имеем в наличии internal реализацию стандартных функций.

function loadfile(file)
  checkArg(1, file, "string");

  local jandle, reason = rom.open(file); -- открываем фаил

  if( not jandle ) then
    error(string.fmt("Не удалось открыть :%s: %s", file, reason));
  end

  local buffer, counter = '', 0;

  repeat
    local data;
    data, reason = rom.read(jandle, math.huge); -- читаем линию из файла

    if ( not data and reason ) then
      error(string.fmt("Не удалось прочитать :%s: %s", file, reason));
    end

    buffer = buffer .. (data or "");
    counter = counter + 1;
  until not data;

  rom.close(jandle);

  -- загружаем текстовый буфер

  jandle, reason = load(buffer, "=" .. file);

  if( not jandle ) then
    error(string.fmt("Ошибка синтаксиса в файле :%s: %s", file, tostring(reason)));
  end

  return jandle; 
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

  return reason;
end

-- подаем сигнал о том что инициализация завершилась

computer.beep(1000, 0.2)

-- замораживаем работу скрипта, т.к. выход из него пораждает ошибку computer halted (!)
ask("Продолжить выполнение скрипта вкачестве слушателя событий и вывода их на экран?", {good = "No", "Yes"}, nil, function()
  print(string.fmt("dropped to the main event cycle. RAM (%i/%i) kib", computer.freeMemory()/1024, computer.totalMemory()/1024));
  while true do print(computer.pullSignal()); end
end);



--[[
  component.list(); -- возращает таблицу
  component.list(stringName); -- возвращает таблицу
  component.invoke(stringAddress, stringMethod, vaArguments); -- метод включения метода по адресу.
  component.proxy(stringDddress); -- возращает более юзабельный объект, для которого можно напрямую вызывать методы по имени, без invoke.

  -- eeprom - компонент, наш загрузочный скрипт

  eeprom.getData():stringAddress - возращает адрес filesystem с которой он загрузил init.lua

  -- rom - компонент filesystem
  rom.open(stringFile);
  rom.read(numberHandle, numberSize);
  rom.close(numberHandle) 

    Для работы со внешним интерфейсом, используется функция computer.pullSignal(). Читать тут http://minecraft-ru.gamepedia.com/OpenComputers/%D0%A1%D0%B8%D0%B3%D0%BD%D0%B0%D0%BB%D1%8B
  во внешний интерйес входят клавиатуры, мониторы, и т.д. смотреть по ссылке перечень событий.

    Для работы со внутренним устройством, используется component. С его помощью можно использовать функции встроенных модулей. 
  Читать тут http://minecraft-ru.gamepedia.com/OpenComputers/Component_API

    Оффициальный доки
  http://ocdoc.cil.li/

    Дамп _G таблицы из скрипта init.lua:

        1. boot_invoke : function
        2. coroutine : table
        3. table : table
        4. load : function
        5. rawget : function
        6. tonumber : function
        5. bit32 : table
        6. unicode : table
        7. computer : table
        8. debug : table
        9. rawset : function
       10. xpcall : function 
       11. checkArg : function
       12. next : function
       13. setmetatable : function
       14. pcall : function
       15. assert : function
       16. getmetatable : function
       17. rawlen : function 
       18. error : function
       19. math : table
       20. type : function
       21. component : table
       22. os : table
       23. string : table
       24. _VERSION : "Lua 5.2"
       25. tostring : function
       26. rawequal : function
       27. pairs : function
       28. select : function
       29. ipairs : function
]]

-- убераем флаг инициализации

_G.IN_INIT = nil;