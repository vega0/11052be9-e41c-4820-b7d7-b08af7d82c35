-- добавляем функцию в table для конкатернации таблиц с опущенным клюем (!) порядок параметров не сохраняется

function table.concat_raw( ... )
  local stack = {...};
  for _, v in pairs( tbl ) do
    table.insert(stack, tostring(v));
  end
  return table.concat(stack);
end