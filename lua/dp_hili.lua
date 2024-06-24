local M = {}

local sta, B = pcall(require, 'dp_base')

if not sta then return print('Dp_base is required!', debug.getinfo(1)['source']) end

if B.check_plugins {
      'folke/which-key.nvim',
    } then
  return
end

-- 1. [x] TODODONE: <c-s-n> error on single (, no big deal
-- 2. [ ] TODO: <c-.> not working, deal to inputmethod

-- M.hl_cursorword = { bg = '#338822', fg = '#eeff11', reverse = false, bold = true, }
-- M.hl_lastcursorword = { fg = '#aaaa00', bg = '#773399', reverse = false, bold = true, }

M.hl_cursorword = { reverse = true, bold = true, }
M.hl_lastcursorword = { reverse = true, bold = false, }

M.HiLi = {}

M.curcontent = ''

M.hicurword = 1
M.windo = nil

M.ignore_fts = { 'minimap', }

M.iskeyword_pattern = '^[%w_一-龥]+$'

M.two_cwords = {}

if not M.last_hls then
  M.last_hls = {}
end

M.cursorword_lock = nil

function M.gethiname(content)
  local sha256 = require 'sha2'
  local res = tostring(sha256.sha256(content))
  return 'H' .. string.sub(res, 1, 7)
end

function M.getescape(content)
  content = string.gsub(content, '%[', '\\[')
  content = string.gsub(content, '%*', '\\*')
  content = string.gsub(content, '%.', '\\.')
  content = string.gsub(content, '%~', '\\~')
  content = string.gsub(content, '%$', '\\$')
  content = string.gsub(content, '%^', '\\^')
  return content
end

function M.getcontent(line1, col1, line2, col2)
  local lines = {}
  for lnr = line1, line2 do
    local line = vim.fn.getline(lnr)
    if lnr == line1 and lnr == line2 then
      local linetemp1 = string.sub(line, col1, col2 + 1)
      local linetemp2 = string.sub(line, col1, col2 + 2)
      line = string.sub(line, col1, col2)
      if vim.fn.strdisplaywidth(linetemp1) == vim.fn.strdisplaywidth(line) + 4 and vim.fn.strdisplaywidth(linetemp1) == vim.fn.strdisplaywidth(linetemp2) + 6 then
        line = linetemp2
      end
    else
      if lnr == line1 then
        line = string.sub(line, col1)
      elseif lnr == line2 then
        local linetemp1 = string.sub(line, col1, col2 + 1)
        local linetemp2 = string.sub(line, col1, col2 + 2)
        line = string.sub(line, 0, col2)
        if vim.fn.strdisplaywidth(linetemp1) == vim.fn.strdisplaywidth(line) + 4 and vim.fn.strdisplaywidth(linetemp1) == vim.fn.strdisplaywidth(linetemp2) + 6 then
          line = linetemp2
        end
      end
    end
    local cells = {}
    for ch in string.gmatch(line, '.') do
      if ch == "'" then
        table.insert(cells, [["'"]])
      else
        if vim.tbl_contains({ '\\', '/', }, ch) then
          ch = '\\' .. ch
        end
        table.insert(cells, string.format("'%s'", ch))
      end
    end
    if #cells > 0 then
      table.insert(lines, table.concat(cells, ' . '))
    else
      table.insert(lines, "''")
    end
  end
  if #lines == 0 then
    return "''"
  end
  local content = table.concat(lines, " . '\\n' . ")
  return content
end

function M.getvisualcontent()
  local s = vim.fn.getpos "'<"
  local line1 = s[2]
  local col1 = s[3]
  local e = vim.fn.getpos "'>"
  local line2 = e[2]
  local col2 = e[3]
  return M.getcontent(line1, col1, line2, col2)
end

function M.search_next()
  local temp = vim.fn.getreg '/'
  if not B.is(temp) then
    return
  end
  vim.fn.search(temp)
  M.print_cword(temp)
end

function M.search_prev()
  local temp = vim.fn.getreg '/'
  if not B.is(temp) then
    return
  end
  vim.fn.search(temp, 'b')
  M.print_cword(temp)
end

function M.search()
  vim.cmd [[call feedkeys("\<esc>")]]
  local timer = vim.loop.new_timer()
  timer:start(10, 0, function()
    vim.schedule(function()
      B.cmd('let @/ = "\\V" . %s', M.getvisualcontent())
      vim.cmd [[call feedkeys("/\\\<c-r>/\<cr>")]]
    end)
  end)
end

function M.colorinit()
  local light = require 'nvim-web-devicons.icons-light'
  local by_filename = light.icons_by_filename
  Colors = {}
  for _, v in pairs(by_filename) do
    table.insert(Colors, v['color'])
  end
end

M.colorinit()

function M.gethilipath()
  return require 'plenary.path':new(vim.loop.cwd()):joinpath '.hili'
end

function M.gethili()
  local hilipath = M.gethilipath()
  if not hilipath:exists() then
    return {}
  end
  local res = hilipath:read()
  local hili
  if #res > 0 then
    hili = loadstring('return ' .. res)()
  else
    hili = {}
  end
  return hili
end

function M.savehili(content, bg)
  local hili = M.gethili()
  if bg then
    hili = vim.tbl_deep_extend('force', hili, { [content] = bg, })
  else
    hili[content] = nil
  end
  if #vim.tbl_keys(hili) == 0 then
    M.gethilipath():rm()
  else
    M.gethilipath():write(vim.inspect(hili), 'w')
  end
end

function M.hili_v()
  M.HiLi = M.gethili()
  if vim.tbl_contains({ 'v', 'V', '', }, vim.fn.mode()) == true then
    vim.cmd [[call feedkeys("\<esc>")]]
    local timer = vim.loop.new_timer()
    timer:start(10, 0, function()
      vim.schedule(function()
        B.cmd('let @0 = %s', M.getvisualcontent())
        local content = M.getescape(vim.fn.getreg '0')
        local hiname = M.gethiname(content)
        local bg = Colors[math.random(#Colors)]
        M.HiLi = vim.tbl_deep_extend('force', M.HiLi, { [content] = bg, })
        M.savehili(content, bg)
        vim.api.nvim_set_hl(0, hiname, { bg = bg, })
        vim.fn.matchadd(hiname, content)
      end)
    end)
  end
end

function M.hili_n()
  vim.cmd 'norm viw'
  M.hili_v()
end

function M.rmhili_do(content)
  local hiname = M.gethiname(content)
  pcall(vim.fn.matchdelete, vim.api.nvim_get_hl_id_by_name(hiname))
  vim.api.nvim_set_hl(0, hiname, { bg = nil, fg = nil, bold = nil, })
end

function M.rmhili_v()
  M.HiLi = M.gethili()
  if M.HiLi and #vim.tbl_keys(M.HiLi) > 0 then
    if vim.tbl_contains({ 'v', 'V', '', }, vim.fn.mode()) == true then
      vim.cmd [[call feedkeys("\<esc>")]]
      local timer = vim.loop.new_timer()
      timer:start(10, 0, function()
        vim.schedule(function()
          B.cmd('let @0 = %s', M.getvisualcontent())
          local content = M.getescape(vim.fn.getreg '0')
          if vim.tbl_contains(vim.tbl_keys(M.HiLi), content) then
            M.rmhili_do(content)
            M.savehili(content, nil)
          end
        end)
      end)
    end
  end
end

function M.rmhili_n()
  vim.cmd 'norm viw'
  M.rmhili_v()
end

function M.hili_do(content, val)
  local hiname = M.gethiname(content)
  vim.api.nvim_set_hl(0, hiname, val)
  vim.fn.matchadd(hiname, content)
end

function M.rehili()
  M.HiLi = M.gethili()
  if M.HiLi and #vim.tbl_keys(M.HiLi) > 0 then
    for content, bg in pairs(M.HiLi) do
      M.hili_do(content, { bg = bg, })
    end
  end
end

function M.print_cword(cword)
  local searchcount = vim.fn.searchcount { pattern = cword, maxcount = 999999, }
  B.echo('[%d/%d] %s', searchcount['current'], searchcount['total'], string.gsub(cword, "'", '"'))
end

function M.prevhili()
  M.HiLi = M.gethili()
  if M.HiLi and #vim.tbl_keys(M.HiLi) > 0 then
    vim.cmd [[call feedkeys("\<esc>")]]
    local content = table.concat(vim.tbl_keys(M.HiLi), '\\|')
    local ee = vim.fn.searchpos(content, 'be')
    local ss = vim.fn.searchpos(content, 'bn')
    B.cmd('let @0 = %s', M.getcontent(ss[1], ss[2], ee[1], ee[2]))
    M.curcontent = M.getescape(vim.fn.getreg '0')
    M.print_cword(content)
  end
end

function M.nexthili()
  M.HiLi = M.gethili()
  if M.HiLi and #vim.tbl_keys(M.HiLi) > 0 then
    vim.cmd [[call feedkeys("\<esc>")]]
    local content = table.concat(vim.tbl_keys(M.HiLi), '\\|')
    local ss = vim.fn.searchpos(content)
    local ee = vim.fn.searchpos(content, 'ne')
    B.cmd('let @0 = %s', M.getcontent(ss[1], ss[2], ee[1], ee[2]))
    M.curcontent = M.getescape(vim.fn.getreg '0')
    M.print_cword(content)
  end
end

function M.border(content)
  if content:sub(1, 1):match '%w' then
    content = '\\<' .. content
  end
  if content:sub(#content, #content):match '%w' then
    content = content .. '\\>'
  end
  return content
end

function M.prevcword()
  local cword = M.border(vim.fn.expand '<cword>')
  vim.fn.search(cword, 'b')
  M.print_cword(cword)
end

function M.nextcword()
  local cword = M.border(vim.fn.expand '<cword>')
  vim.fn.search(cword)
  M.print_cword(cword)
end

function M.prevcWORD()
  local cword = M.border(vim.fn.expand '<cWORD>')
  vim.fn.search(cword, 'b')
  M.print_cword(cword)
end

function M.nextcWORD()
  local cword = M.border(vim.fn.expand '<cWORD>')
  vim.fn.search(cword)
  M.print_cword(cword)
end

function M.prevlastcword()
  local cword = M.border(M.lastcword)
  vim.fn.search(cword, 'b')
  M.print_cword(cword)
end

function M.nextlastcword()
  local cword = M.border(M.lastcword)
  vim.fn.search(cword)
  M.print_cword(cword)
end

function M.prevcurhili()
  M.HiLi = M.gethili()
  if #M.curcontent > 0 then
    vim.cmd [[call feedkeys("\<esc>")]]
    vim.fn.searchpos(M.curcontent, 'be')
    M.print_cword(M.curcontent)
  end
end

function M.nextcurhili()
  M.HiLi = M.gethili()
  if #M.curcontent > 0 then
    vim.cmd [[call feedkeys("\<esc>")]]
    vim.fn.searchpos(M.curcontent)
    M.print_cword(M.curcontent)
  end
end

function M.selnexthili()
  M.HiLi = M.gethili()
  if M.HiLi and #vim.tbl_keys(M.HiLi) > 0 then
    vim.cmd [[call feedkeys("\<esc>")]]
    local content = table.concat(vim.tbl_keys(M.HiLi), '\\|')
    local n = vim.fn.searchpos(content, 'n')
    local ne = vim.fn.searchpos(content, 'ne')
    if n[1] == ne[1] and n[2] == ne[2] then
      vim.fn.searchpos(content)
      vim.cmd [[call feedkeys("\<c-v>v")]]
    else
      vim.fn.searchpos(content)
      local width = vim.fn.strdisplaywidth(string.sub(vim.fn.getline(ne[1]), 1, ne[2]))
      B.cmd([[call feedkeys("v%dgg%d|")]], ne[1], width)
    end
  end
end

function M.selprevhili()
  M.HiLi = M.gethili()
  if M.HiLi and #vim.tbl_keys(M.HiLi) > 0 then
    vim.cmd [[call feedkeys("\<esc>")]]
    local content = table.concat(vim.tbl_keys(M.HiLi), '\\|')
    local nb = vim.fn.searchpos(content, 'nb')
    local nbe = vim.fn.searchpos(content, 'nbe')
    if nbe[1] == nb[1] and nbe[2] == nb[2] then
      vim.fn.searchpos(content, 'be')
      vim.cmd [[call feedkeys("\<c-v>v")]]
    else
      vim.fn.searchpos(content, 'be')
      local ne = vim.fn.searchpos(content, 'nb')
      local width = vim.fn.strdisplaywidth(string.sub(vim.fn.getline(ne[1]), 1, ne[2]))
      B.cmd([[call feedkeys("v%dgg%d|")]], ne[1], width)
    end
  end
end

function M.hili_lastcursorword(word)
  B.stack_item(M.two_cwords, word, 2)
  for _, i in ipairs(M.last_hls) do
    M.rmhili_do(i)
  end
  M.lastcword = M.two_cwords[1]
  if not M.lastcword then
    return
  end
  local w = M.border(M.lastcword)
  M.hili_do(w, M.hl_lastcursorword)
  M.last_hls[#M.last_hls + 1] = w
end

function M.on_cursormoved(ev)
  local filetype = vim.api.nvim_buf_get_option(ev.buf, 'filetype')
  if vim.tbl_contains(M.ignore_fts, filetype) == true then
    return
  end
  local just_hicword = nil
  local word = vim.fn.expand '<cword>'
  if M.hicurword then
    if M.windo then
      if vim.fn.getbufvar(ev.buf, '&buftype') ~= 'nofile' then
        local winid = vim.fn.win_getid()
        if string.match(word, M.iskeyword_pattern) then
          M.hili_lastcursorword(word)
          B.cmd([[keepj windo match CursorWord /\V\<%s\>/]], word)
        else
          vim.cmd [[keepj windo match CursorWord //]]
        end
        vim.fn.win_gotoid(winid)
      else
        just_hicword = 1
      end
    else
      just_hicword = 1
    end
  else
    vim.cmd [[match CursorWord //]]
  end
  if just_hicword then
    if string.match(word, M.iskeyword_pattern) then
      M.hili_lastcursorword(word)
      B.cmd([[match CursorWord /\V\<%s\>/]], word)
    else
      vim.cmd [[match CursorWord //]]
    end
  end
end

function M.windocursorword()
  if M.windo then
    M.windo = nil
    B.notify_info 'do not windo match'
  else
    M.windo = 1
    B.notify_info 'windo match'
  end
  M.on_cursormoved { buf = vim.fn.bufnr(), }
end

function M.cursorword()
  if M.hicurword then
    M.hicurword = nil
    B.notify_info 'do not cursorword'
  else
    M.hicurword = 1
    B.notify_info 'cursorword'
  end
  M.on_cursormoved { buf = vim.fn.bufnr(), }
end

function M.on_colorscheme()
  M.rehili()
  vim.api.nvim_set_hl(0, 'CursorWord', M.hl_cursorword)
end

M.on_colorscheme()

B.aucmd({ 'CursorHold', 'CursorHoldI', 'CursorMoved', 'CursorMovedI', }, 'my.hili.CursorMoved', {
  callback = function(ev)
    if M.cursorword_lock then
      return
    end
    M.cursorword_lock = 1
    B.set_timeout(vim.o.updatetime, function()
      M.cursorword_lock = nil
    end)
    M.on_cursormoved(ev)
  end,
})

B.aucmd({ 'InsertLeave', }, 'my.hili.InsertLeave', {
  callback = function(ev)
    M.hicurword = M.hicurword_back
    M.on_cursormoved(ev)
    M.hili_lastcursorword(M.lastcword)
  end,
})

B.aucmd({ 'InsertEnter', }, 'my.hili.InsertEnter', {
  callback = function(ev)
    M.hicurword_back = M.hicurword
    M.hicurword = nil
    M.on_cursormoved(ev)
    for _, i in ipairs(M.last_hls) do
      M.rmhili_do(i)
    end
  end,
})

B.aucmd({ 'ColorScheme', }, 'my.hili.ColorScheme', {
  callback = function()
    M.on_colorscheme()
  end,
})

require 'which-key'.register {
  ['n'] = { function() M.search_next() end, 'hili: search next', mode = { 'n', 'v', }, silent = true, },
  ['N'] = { function() M.search_prev() end, 'hili: search prev', mode = { 'n', 'v', }, silent = true, },
  ['*'] = { function() M.search() end, 'hili: multiline search', mode = { 'v', }, silent = true, },
  -- windo cursorword
  ['<a-7>'] = { function() M.cursorword() end, 'hili: cursor word', mode = { 'n', }, silent = true, },
  ['<a-8>'] = { function() M.windocursorword() end, 'hili: windo cursor word', mode = { 'n', }, silent = true, },
  -- cword hili
  ['<c-8>'] = { function() M.hili_v() end, 'hili: cword', mode = { 'v', }, silent = true, },
  -- cword hili rm
  ['<c-s-8>'] = { function() M.rmhili_v() end, 'hili: rm v', mode = { 'v', }, silent = true, },
  -- select hili
  ['<c-7>'] = { function() M.selnexthili() end, 'hili: sel next', mode = { 'n', 'v', }, silent = true, },
  ['<c-s-7>'] = { function() M.selprevhili() end, 'hili: sel prev', mode = { 'n', 'v', }, silent = true, },
  -- go hili
  ['<c-n>'] = { function() M.prevhili() end, 'hili: go prev', mode = { 'n', 'v', }, silent = true, },
  ['<c-m>'] = { function() M.nexthili() end, 'hili: go next', mode = { 'n', 'v', }, silent = true, },
  -- go cur hili
  ['<c-s-n>'] = { function() M.prevcurhili() end, 'hili: go cur prev', mode = { 'n', 'v', }, silent = true, },
  ['<c-s-m>'] = { function() M.nextcurhili() end, 'hili: go cur next', mode = { 'n', 'v', }, silent = true, },
  -- rehili
  ['<c-s-9>'] = { function() M.rehili() end, 'hili: rehili', mode = { 'n', 'v', }, silent = true, },
  -- search cword
  ["<c-s-'>"] = { function() M.prevlastcword() end, 'hili: prevlastcword', mode = { 'n', 'v', }, silent = true, },
  ['<c-s-/>'] = { function() M.nextlastcword() end, 'hili: nextlastcword', mode = { 'n', 'v', }, silent = true, },
  ['<c-,>'] = { function() M.prevcword() end, 'hili: prevcword', mode = { 'n', 'v', }, silent = true, },
  ['<c-.>'] = { function() M.nextcword() end, 'hili: nextcword', mode = { 'n', 'v', }, silent = true, },
  ["<c-'>"] = { function() M.prevcWORD() end, 'hili: prevcWORD', mode = { 'n', 'v', }, silent = true, },
  ['<c-/>'] = { function() M.nextcWORD() end, 'hili: nextcWORD', mode = { 'n', 'v', }, silent = true, },
}

require 'which-key'.register {
  ['<c-8>'] = { function() M.hili_n() end, 'hili: cword', mode = { 'n', }, silent = true, },
  ['<c-s-8>'] = { function() M.rmhili_n() end, 'hili: rm n', mode = { 'n', }, silent = true, },
}

return M
