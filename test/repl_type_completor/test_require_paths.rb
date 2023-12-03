# frozen_string_literal: true

require 'repl_type_completor'
require_relative './helper'
require 'tmpdir'

module TestReplTypeCompletor
  class RequirePathsTest < TestCase
    def test_require_paths
      assert_include ReplTypeCompletor::RequirePaths.require_completions('repl_type_com'), 'repl_type_completor'
      assert_include ReplTypeCompletor::RequirePaths.require_completions('repl_type_com'), 'repl_type_completor/version'
      assert_equal ['repl_type_completor/version'], ReplTypeCompletor::RequirePaths.require_completions('repl_type_completor/vers')
    end

    def test_require_relative_paths
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('test_re', __FILE__), 'test_require_paths'
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('../repl_', __FILE__), '../repl_type_completor/test_require_paths'
      project_root = File.expand_path('../../Gemfile', __dir__)
      assert_not_include ReplTypeCompletor::RequirePaths.require_relative_completions('li', __FILE__), 'lib/repl_type_completor'
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_type_completor'
      # Incrementally complete deep path
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_type_completor/'
      assert_not_include ReplTypeCompletor::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_type_completor/version'
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('lib/', project_root), 'lib/repl_type_completor/version'
    end

    def clear_cache
      ReplTypeCompletor::RequirePaths.instance_eval do
        remove_instance_variable(:@gem_and_system_load_paths) if defined? @gem_and_system_load_paths
        remove_instance_variable(:@cache) if defined? @cache
      end
    end

    def test_require_paths_no_duplication
      # When base_dir/ base_dir/3.3.0 base_dir/3.3.0/arm64-darwin are in $LOAD_PATH,
      # "3.3.0/arm64-darwin/file", "arm64-darwin/file" and "file" will all require the same file.
      # Completion candidates should only include the shortest one.
      load_path_backup = $LOAD_PATH.dup
      dir0 = Dir.mktmpdir
      dir1 = File.join(dir0, '3.3.0')
      dir2 = File.join(dir1, 'arm64-darwin')
      dir3 = File.join(dir1, 'test_req_dir')
      Dir.mkdir dir1
      Dir.mkdir dir2
      Dir.mkdir dir3
      File.write File.join(dir0, 'test_require_a.rb'), ''
      File.write File.join(dir1, 'test_require_a.rb'), ''
      File.write File.join(dir2, 'test_require_a.rb'), ''
      File.write File.join(dir0, 'test_require_b.rb'), ''
      File.write File.join(dir1, 'test_require_c.rb'), ''
      File.write File.join(dir1, 'arm64-darwin-foobar.rb'), ''
      File.write File.join(dir2, 'test_require_d.rb'), ''
      File.write File.join(dir3, 'test_require_e.rb'), ''
      $LOAD_PATH.push(dir0, dir1, dir2)
      clear_cache

      files = %w[test_req_dir/test_require_e test_require_a test_require_b test_require_c test_require_d]
      assert_equal files, ReplTypeCompletor::RequirePaths.require_completions('test_req').sort
      candidates = ReplTypeCompletor::RequirePaths.require_completions('')
      assert_include candidates, 'arm64-darwin-foobar'
      files.each do |path|
        assert_not_include candidates, "3.3.0/#{path}"
        assert_not_include candidates, "3.3.0/arm64-darwin/#{path}"
        assert_not_include candidates, "arm64-darwin/#{path}"
      end
    ensure
      $LOAD_PATH.replace load_path_backup
    end
  end
end
