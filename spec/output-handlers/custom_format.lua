local pretty = require 'pl.pretty'
local term = require 'term'

local colors

local isatty = io.type(io.stdout) == 'file' and term.isatty(io.stdout)

local isWindows = package.config:sub(1,1) == '\\'

if isWindows and not os.getenv("ANSICON") then
  colors = setmetatable({}, {__index = function() return function(s) return s end end})
  isatty = false
else
  colors = require 'term.colors'
end

local clreol = "\27[K"
local cursorup = isatty and "\27[1A" or ""

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.base'()

  local repeatSuiteString = '\nRepeating all tests (run %u of %u) . . .\n\n'
  local randomizeString  = colors.yellow('Note: Randomizing test order with a seed of %u.\n')
  local suiteStartString = colors.green  ('=======') .. ' Running tests from scanned files.\n'
  local globalSetup      = colors.green  ('-------') .. ' Global test environment setup.\n'
  local fileStartString  = colors.green  ('-------') .. ' Running tests from ' .. colors.cyan('%s') .. ' :\n'
  local runningString    = colors.green  (' RUN') .. ' %s'
  local successString    = colors.green  ('  OK') .. clreol .. ' %s'
  local skippedString    = colors.yellow ('SKIP') .. clreol .. ' %s'

  local failureStartString   = colors.red ('        __________' .. clreol .. '\n        FAIL') .. ' %s'
  local failureString        = colors.red ('__________')

  local errorStartString  = colors.magenta('        __________' .. clreol .. '\n         ERR') .. ' %s'
  local errorString       = colors.magenta('__________')
  local errorAltEndString = colors.magenta('        __________') .. '\n\n'

  local fileEndString    = colors.green  ('-------') .. ' %u %s from %s (%.2f ms total)\n\n'
  local globalTeardown   = colors.green  ('-------') .. ' Global test environment teardown.\n'
  local suiteEndString   = colors.green  ('=======') .. ' %u %s from %u test %s ran. (%.2f ms total)\n'
  local successStatus    = colors.green  ('PASSED ') .. ' %u %s.\n\n'

  local summaryStrings = {
    skipped = {
      header = 'SKIPPED %u %s, listed below:\n',
      test   = colors.yellow ('SKIPPED') .. ' %s\n',
      footer = ' %u SKIPPED %s\n',
    },

    failure = {
      header = ' FAILED %u %s, listed below:\n',
      test   = colors.red    (' FAILED') .. ' %s\n',
      footer = ' %u FAILED %s\n',
    },

    error = {
      header = '  ERROR %u %s, listed below:\n',
      test   = colors.magenta('  ERROR') .. ' %s\n',
      footer = ' %u %s\n',
    },
  }

  local fileCount = 0
  local fileTestCount = 0
  local testCount = 0
  local successCount = 0
  local skippedCount = 0
  local failureCount = 0
  local errorCount = 0

  local pendingDescription = function(pending)
    local string = ''

    if type(pending.message) == 'string' then
      string = string .. pending.message .. '\n'
    elseif pending.message ~= nil then
      string = string .. pretty.write(pending.message) .. '\n'
    end

    return string
  end

  local failureDescription = function(failure)
    local string = failure.randomseed and ('Random seed: ' .. failure.randomseed .. '\n') or ''
    if type(failure.message) == 'string' then
      string = string .. failure.message
    elseif failure.message == nil then
      string = string .. 'Nil error'
    else
      string = string .. pretty.write(failure.message)
    end

    string = '\n' .. string .. '\n'

    if options.verbose and failure.trace and failure.trace.traceback then
      string = string .. failure.trace.traceback .. '\n'
    end

    return string
  end

  local getFileLine = function(element)
    local fileline = ''
    if element.trace and element.trace.source then
      fileline = colors.cyan(element.trace.source:gsub("^@", "")) .. ':' ..
                 colors.cyan(element.trace.currentline) .. ': '
    end
    return fileline
  end

  local getTestList = function(status, count, list, getDescription)
    local string = ''
    local header = summaryStrings[status].header
    if count > 0 and header then
      local tests = (count == 1 and 'test' or 'tests')
      local errors = (count == 1 and 'error' or 'errors')
      string = header:format(count, status == 'error' and errors or tests)

      local testString = summaryStrings[status].test
      if testString then
        for _, t in ipairs(list) do
          local fullname = getFileLine(t.element) .. colors.bright(t.name)
          string = string .. testString:format(fullname)
          if options.deferPrint then
            string = string .. getDescription(t)
          end
        end
      end
    end
    return string
  end

  local getSummary = function(status, count)
    local string = ''
    local footer = summaryStrings[status].footer
    if count > 0 and footer then
      local tests = (count == 1 and 'TEST' or 'TESTS')
      local errors = (count == 1 and 'ERROR' or 'ERRORS')
      string = footer:format(count, status == 'error' and errors or tests)
    end
    return string
  end

  local getSummaryString = function()
    local tests = (successCount == 1 and 'test' or 'tests')
    local string = successStatus:format(successCount, tests)

    string = string .. getTestList('skipped', skippedCount, handler.pendings, pendingDescription)
    string = string .. getTestList('failure', failureCount, handler.failures, failureDescription)
    string = string .. getTestList('error', errorCount, handler.errors, failureDescription)

    string = string .. ((skippedCount + failureCount + errorCount) > 0 and '\n' or '')
    string = string .. getSummary('skipped', skippedCount)
    string = string .. getSummary('failure', failureCount)
    string = string .. getSummary('error', errorCount)

    return string
  end

  local getTestName = function(element)
    local out = {}
    for text, hashtag in handler.getFullName(element):gmatch("([^#]*)(#?[%w_-]*)") do
      table.insert(out, colors.bright(text))
      table.insert(out, colors.bright(colors.cyan(hashtag)))
    end
    return table.concat(out)
  end

  local getFullName = function(element)
    return getFileLine(element) .. getTestName(element)
  end
  
  local clock = function(ms)
    if ms < 1000 then
      return colors.cyan(("%7.2f"):format(ms))
    elseif ms < 10000 then
      return colors.yellow(("%7.2f"):format(ms))
    else
      return colors.bright(colors.red(("%7.2f"):format(ms)))
    end
  end

  handler.suiteReset = function()
    fileCount = 0
    fileTestCount = 0
    testCount = 0
    successCount = 0
    skippedCount = 0
    failureCount = 0
    errorCount = 0

    return nil, true
  end

  handler.suiteStart = function(suite, count, total, randomseed)
    if total > 1 then
      io.write(repeatSuiteString:format(count, total))
    end
    if randomseed then
      io.write(randomizeString:format(randomseed))
    end
    io.write(suiteStartString)
    io.write(globalSetup)
    io.flush()

    return nil, true
  end

  handler.suiteEnd = function(suite, count, total)
    local elapsedTime_ms = suite.duration * 1000
    local tests = (testCount == 1 and 'test' or 'tests')
    local files = (fileCount == 1 and 'file' or 'files')
    io.write(globalTeardown)
    io.write(suiteEndString:format(testCount, tests, fileCount, files, elapsedTime_ms))
    io.write(getSummaryString())
    io.flush()

    return nil, true
  end

  handler.fileStart = function(file)
    fileTestCount = 0

    io.write(fileStartString:format(file.name))
    io.flush()
    return nil, true
  end

  handler.fileEnd = function(file)
    local elapsedTime_ms = file.duration * 1000
    local tests = (fileTestCount == 1 and 'test' or 'tests')
    fileCount = fileCount + 1
    io.write(fileEndString:format(fileTestCount, tests, file.name, elapsedTime_ms))
    io.flush()
    return nil, true
  end

  handler.testStart = function(element, parent)
    if isatty then
      local successName = colors.cyan(element.trace.currentline) .. ': '.. getTestName(element)
      local str = '....... ' .. runningString:format(successName) .. '\n'
      io.write(str)
      io.flush()
    end

    return nil, true
  end

  handler.testEnd = function(element, parent, status, debug)
    local elapsedTime_ms = element.duration * 1000
    local string

    fileTestCount = fileTestCount + 1
    testCount = testCount + 1
    local successName = colors.cyan(element.trace.currentline) .. ': '.. getTestName(element)
    if status == 'success' then
      io.write(cursorup)
      successCount = successCount + 1
      string = clock(elapsedTime_ms) .. ' ' .. successString:format(successName) .. '\n'
    elseif status == 'pending' then
      io.write(cursorup)
      skippedCount = skippedCount + 1
      string = '        ' .. skippedString:format(successName) .. '\n'
    elseif status == 'failure' then
      failureCount = failureCount + 1
      string = clock(elapsedTime_ms) .. ' ' .. failureString .. '\n\n'
    elseif status == 'error' then
      errorCount = errorCount + 1
      string = clock(elapsedTime_ms) .. ' ' .. errorString ..  '\n\n'
    end

    io.write(string)
    io.flush()

    return nil, true
  end

  handler.testFailure = function(element, parent, message, debug)
    if not options.deferPrint then
      io.write(failureStartString:format(getFullName(element)))
      io.write(failureDescription(handler.failures[#handler.failures]))
      io.flush()
    end
    return nil, true
  end

  handler.testError = function(element, parent, message, debug)
    if not options.deferPrint then
      io.write(errorStartString:format(getFullName(element)))
      io.write(failureDescription(handler.errors[#handler.errors]))
      io.flush()
    end
    return nil, true
  end

  handler.error = function(element, parent, message, debug)
    if element.descriptor ~= 'it' then
      if not options.deferPrint then
        io.write(errorStartString:format(getFullName(element)))
        io.write(failureDescription(handler.errors[#handler.errors]))
        io.write(errorAltEndString)
        io.flush()
      end
      errorCount = errorCount + 1
    end

    return nil, true
  end

  busted.subscribe({ 'suite', 'reset' }, handler.suiteReset)
  busted.subscribe({ 'suite', 'start' }, handler.suiteStart)
  busted.subscribe({ 'suite', 'end' }, handler.suiteEnd)
  busted.subscribe({ 'file', 'start' }, handler.fileStart)
  busted.subscribe({ 'file', 'end' }, handler.fileEnd)
  busted.subscribe({ 'test', 'start' }, handler.testStart, { predicate = handler.cancelOnPending })
  busted.subscribe({ 'test', 'end' }, handler.testEnd, { predicate = handler.cancelOnPending })
  busted.subscribe({ 'failure', 'it' }, handler.testFailure)
  busted.subscribe({ 'error', 'it' }, handler.testError)
  busted.subscribe({ 'failure' }, handler.error)
  busted.subscribe({ 'error' }, handler.error)

  return handler
end