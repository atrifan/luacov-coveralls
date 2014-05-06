
local coveralls = {}

local json = require "json"
local luacov_reporter = require "luacov.reporter"

local ReporterBase = luacov_reporter.ReporterBase

----------------------------------------------------------------
local CoverallsReporter = setmetatable({}, ReporterBase) do
CoverallsReporter.__index = CoverallsReporter

local EMPTY = json.decode('null')
local ZERO  = 0

local function debug_print(o, ...)
   if not o._debug then return end
   io.stdout:write(...)
end

function CoverallsReporter:new(conf)
   local o, err = ReporterBase.new(self, conf)
   if not o then return nil, err end

   -- read coveralls specific configurations
   local cc = conf.coveralls
   if cc then
      self._debug = not not cc.debug

      if cc.pathcorrect then
         local pat = {}
         -- @todo implement function as path converter?
         for i, p in ipairs(cc.pathcorrect) do
            assert(type(p)    == "table")
            assert(type(p[1]) == "string")
            assert(type(p[2]) == "string")
            pat[i] = {p[1], p[2]}
            debug_print(o, "Add correct path: `", p[1], "` => `", p[2], "`\n")
         end
         o._correct_path_pat = pat
      end
   end

   -- @todo check repo_token (os.getenv("REPO_TOKEN"))
   o._service_name   = 'travis-ci'
   o._service_job_id = os.getenv("TRAVIS_JOB_ID")
   if not o._service_job_id then
      o:close()
      return nil, "You should run this only on Travis-CI."
   end
   o._source_files   = json.util.InitArray{}

   return o
end

function CoverallsReporter:correct_path(path)
   debug_print(self, "correct path: ", path, "=>")

   if self._correct_path_pat then
      for _, pat in ipairs(self._correct_path_pat) do
         path = path:gsub(pat[1], pat[2])
      end
   end

   debug_print(self, path, "\n")
   return path
end

function CoverallsReporter:on_start()
end

function CoverallsReporter:on_new_file(filename)
   self._current_file = {
      name     = self:correct_path(filename);
      source   = {};
      coverage = json.util.InitArray{};
   }
end

function CoverallsReporter:on_empty_line(filename, lineno, line)
   local source_file = self._current_file
   table.insert(source_file.coverage, EMPTY)
   table.insert(source_file.source, line)
end

function CoverallsReporter:on_mis_line(filename, lineno, line)
   local source_file = self._current_file
   table.insert(source_file.coverage, ZERO)
   table.insert(source_file.source, line)
end

function CoverallsReporter:on_hit_line(filename, lineno, line, hits)
   local source_file = self._current_file
   table.insert(source_file.coverage, hits)
   table.insert(source_file.source, line)
end

function CoverallsReporter:on_end_file(filename, hits, miss)
   local source_file = self._current_file
   source_file.source = table.concat(source_file.source, "\n")
   table.insert(self._source_files, source_file)
end

function CoverallsReporter:on_end()
   local msg = json.encode{
      service_name   = self._service_name;
      service_job_id = self._service_job_id;
      source_files   = self._source_files;
   }
   self:write(msg)
end

end
----------------------------------------------------------------

function coveralls.report()
   return luacov_reporter.report(CoverallsReporter)
end

return coveralls
