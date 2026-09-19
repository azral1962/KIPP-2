-- Serialize metadata as Typst literals, preserving false and escaping strings.
local stringify = pandoc.utils.stringify
local function str(value)
  return '"' .. stringify(value):gsub('\\', '\\\\'):gsub('"', '\\"')
    :gsub('\r', '\\r'):gsub('\n', '\\n'):gsub('\t', '\\t') .. '"'
end
local function content(value)
  local kind = pandoc.utils.type(value)
  local blocks = kind == 'Blocks' and value or {pandoc.Plain(value)}
  return '[' .. pandoc.write(pandoc.Pandoc(blocks), 'typst') .. ']'
end
local function raw(value) return pandoc.MetaInlines{pandoc.RawInline('typst', value)} end
local function boolean(value, key)
  if type(value) ~= 'boolean' then error('min-book.' .. key .. ' must be true or false') end
  return tostring(value)
end
local parts = false
local function metadata(meta)
  if not meta.title then error('min-book-quarto requires title (or book.title)') end
  if not meta.author and not meta['by-author'] then error('min-book-quarto requires author (or book.author)') end
  local opts = meta['min-book'] or {}
  local allowed = {}
  for _, key in ipairs{'theme', 'parts', 'part-title', 'chapter-title', 'edition', 'volume',
    'cover', 'titlepage', 'dedication', 'acknowledgements', 'epigraph', 'errata',
    'two-sided', 'paper-friendly', 'draft', 'chapter-continuous', 'std-toc',
    'notes-page', 'back-cover', 'publication-date'} do allowed[key] = true end
  for key in pairs(opts) do
    if not allowed[key] then error('Unknown min-book option: ' .. key) end
  end
  if opts.parts ~= nil then boolean(opts.parts, 'parts') end
  parts = opts.parts == true
  local args, cfg = {}, {}
  local function arg(k, v) args[#args + 1] = k .. ': ' .. v .. ',' end
  local function config(k, v) cfg[#cfg + 1] = k .. ': ' .. v .. ',' end
  local theme = stringify(opts.theme or 'stylish')
  if theme ~= 'stylish' and theme ~= 'coffee' and theme ~= 'elegance' then
    error('min-book.theme must be stylish, coffee, or elegance')
  end
  config('theme', 'themes.' .. theme)
  arg('part', parts and (opts['part-title'] and str(opts['part-title']) or 'auto') or 'none')
  if opts['chapter-title'] then arg('chapter', str(opts['chapter-title'])) end
  for _, key in ipairs{'edition', 'volume'} do
    if opts[key] then
      local n = tonumber(stringify(opts[key]))
      if not n or n < 0 or n % 1 ~= 0 then error('min-book.' .. key .. ' must be a nonnegative integer') end
      arg(key, tostring(n))
    end
  end
  for _, key in ipairs{'cover', 'titlepage'} do
    if opts[key] ~= nil then arg(key, boolean(opts[key], key) == 'true' and 'auto' or 'none') end
  end
  for _, key in ipairs{'dedication', 'acknowledgements', 'epigraph', 'errata'} do
    if opts[key] then arg(key, content(opts[key])) end
  end
  for _, key in ipairs{'two-sided', 'paper-friendly', 'draft', 'chapter-continuous', 'std-toc', 'notes-page'} do
    if opts[key] ~= nil then config(key, boolean(opts[key], key)) end
  end
  if opts['back-cover'] ~= nil then
    config('cover', '(back: ' .. boolean(opts['back-cover'], 'back-cover') .. ',)')
  else config('cover', '(back: false,)') end
  if meta['number-sections'] == false then config('numbering', 'none') end
  -- Publication date is deliberately independent of Quarto's formatted date.
  if opts['publication-date'] then
    local y, m, d = stringify(opts['publication-date']):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not y then error('min-book.publication-date must be YYYY-MM-DD') end
    arg('date', string.format('datetime(year: %d, month: %d, day: %d)', y, m, d))
  end
  meta['min-book-arguments'] = raw(table.concat(args, '\n  '))
  meta['min-book-config-arguments'] = raw(table.concat(cfg, '\n    '))
  local authors = {}
  for _, author in ipairs(meta['by-author'] or {}) do
    authors[#authors + 1] = str(author.name.literal)
  end
  meta['min-book-authors'] = raw('(' .. table.concat(authors, ', ') .. ',)')
  return meta
end
local function header(el)
  local state = quarto.doc.file_metadata()
  local file = state and state.file
  if file and file.bookItemType == 'appendix' then
    error('Automatic book.appendices is not supported yet; use a raw Typst appendices block instead')
  end
  if file and file.bookItemType == 'part' then
    if not parts then error('Book parts require min-book.parts: true') end
  elseif parts and file then
    el.level = el.level + 1
    return el
  end
end
return {
  {Meta = metadata},
  quarto.utils.combineFilters({quarto.utils.file_metadata_filter(), {Header = header}})
}
