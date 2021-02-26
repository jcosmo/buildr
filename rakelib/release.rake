# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

RC_VERSION = ENV['RC_VERSION'] || '' unless defined?(RC_VERSION)

desc 'Release the next version of buildr from existing staged repository'
task 'release' do
  # Push gems to RubyGems.org
  lambda do
    files = FileList["_release/#{spec.version}/dist/*.{gem}"]
    files.each do |f|
      puts "Push gem #{f} to RubyGems.org ... "
      sh 'gem', 'push', f do |ok, res|
          if ok
            puts "[X] Pushed gem #{File.basename(f)} to RubyGems.org"
          else
            puts 'Could not push gem, please do it yourself!'
            puts %{  gem push #{f}}
          end
        end
    end
    puts '[X] Pushed gems to RubyGems.org'
  end.call

  # Create an tag for this release.
  lambda do
    version = `git describe --tags --always`.strip
    unless version == spec.version
      sh 'git', 'tag', '-m', "'Release #{spec.version}'", spec.version.to_s do |ok, res|
        if ok
          puts "[X] Tagged this release as #{spec.version} ... "
          sh 'git', 'push', '--tags'
        else
          puts 'Could not create tag, please do it yourself!'
          puts %{  git tag -m "Release #{spec.version}" #{spec.version} }
        end
      end
    end
  end.call

  # Update CHANGELOG.md to next release number.
  lambda do
    next_version = spec.version.to_s.split('.').map { |v| v.to_i }.
      zip([0, 0, 1]).map { |a| a.inject(0) { |t,i| t + i } }.join('.')
    modified = "#{next_version} (Pending)\n\n" + File.read('CHANGELOG.md')
    File.open 'CHANGELOG.md', 'w' do |file|
      file.write modified
    end
    puts '[X] Updated CHANGELOG.md and added entry for next release'
  end.call

  # Update source files to next release number.
  lambda do
    next_version = spec.version.to_s.split('.').map { |v| v.to_i }.
      zip([0, 0, 1]).map { |a| a.inject(0) { |t,i| t + i } }.join('.')

    ver_file = "lib/#{spec.name}/version.rb"
    if File.exist?(ver_file)
      modified = File.read(ver_file).sub(/(VERSION\s*=\s*)(['"])(.*)\2/) { |line| "#{$1}#{$2}#{next_version}.dev#{$2}" }
      File.open ver_file, 'w' do |file|
        file.write modified
      end
      puts "[X] Updated #{ver_file} to next release"
    end
  end.call

  # Prepare release announcement email.
  lambda do
    changes = File.read("_release/#{spec.version}/CHANGES")[/.*?\n(.*)/m, 1]
    email = <<-EMAIL
To: users@buildr.apache.org
Subject: [ANNOUNCE] Apache Buildr #{spec.version} released

#{spec.description}

New in this release:

#{changes.gsub(/^/, '  ')}

To learn more about Buildr and get started:
http://buildr.apache.org/

Thanks!
The Apache Buildr Team

    EMAIL
    File.open 'announce-email.txt', 'w' do |file|
      file.write email
    end
    puts '[X] Created release announce email template in ''announce-email.txt'''
    puts email
  end.call
end

task('clobber') { rm_rf 'dist' }
task('clobber') { rm_rf '_release' }
task('clobber') { rm_rf 'announce-email.txt' }
