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

module Buildr
  module GWT
    class << self

      def version=(version)
        @version = version
      end

      def version
        @version || Buildr.settings.build['gwt'] || '2.10.0'
      end

      # The specs for requirements
      def dependencies(version = nil)
        validation_deps =
          %w(javax.validation:validation-api:jar:1.0.0.GA javax.validation:validation-api:jar:sources:1.0.0.GA)
        v = version || self.version
        gwt_dev_jar = "com.google.gwt:gwt-dev:jar:#{v}"
        if v == '2.10.0'
          %w(
              com.google.jsinterop:jsinterop-annotations:jar:2.0.0
              com.google.jsinterop:jsinterop-annotations:jar:sources:2.0.0
              org.w3c.css:sac:jar:1.3

              org.gwtproject:gwt-dev:jar:2.10.0
              org.gwtproject:gwt-user:jar:2.10.0
              com.google.code.gson:gson:jar:2.6.2

              org.ow2.asm:asm:jar:9.2
              org.ow2.asm:asm-util:jar:9.2
              org.ow2.asm:asm-tree:jar:9.2
              org.ow2.asm:asm-analysis:jar:9.2
              org.ow2.asm:asm-commons:jar:9.2

              colt:colt:jar:1.2.0

              ant:ant:jar:1.6.5
              commons-collections:commons-collections:jar:3.2.2
              commons-io:commons-io:jar:2.4
              com.ibm.icu:icu4j:jar:63.1
              tapestry:tapestry:jar:4.0.2

              javax.annotation:javax.annotation-api:jar:1.2
              javax.servlet:javax.servlet-api:jar:3.1.0
              org.eclipse.jetty:jetty-annotations:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-continuation:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-http:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-io:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-jndi:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-plus:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-security:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-server:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-servlet:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-servlets:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-util:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-webapp:jar:9.2.14.v20151106
              org.eclipse.jetty:jetty-xml:jar:9.2.14.v20151106
              org.eclipse.jetty.toolchain:jetty-schemas:jar:3.1.M0
          ) + validation_deps
        else
          raise "Unknown GWT version #{v}"
        end
      end

      def gwtc_main(modules, source_artifacts, output_dir, unit_cache_dir, options = {})
        base_dependencies = self.dependencies(options[:version])
        cp = Buildr.artifacts(base_dependencies).each(&:invoke).map(&:to_s) + Buildr.artifacts(source_artifacts).each(&:invoke).map(&:to_s)
        style = options[:style] || 'OBFUSCATED' # 'PRETTY', 'DETAILED'
        log_level = options[:log_level] #  ERROR, WARN, INFO, TRACE, DEBUG, SPAM, or ALL
        workers = options[:workers] || 2

        args = []
        if log_level
          args << '-logLevel'
          args << log_level
        end
        args << '-strict'
        unless style == 'OBFUSCATED'
          args << '-style'
          args << style
        end
        args << '-localWorkers'
        args << workers.to_s
        args << '-war'
        args << output_dir
        if options[:compile_report_dir]
          args << '-compileReport'
          args << '-extra'
          args << options[:compile_report_dir]
        end

        if options[:draft_compile]
          args << '-draftCompile'
        end
        if options[:gwtc_args]
          args += options[:gwtc_args]
        end

        if options[:enable_closure_compiler] && options[:version] == '2.7.0'
          args << '-XenableClosureCompiler'
        end

        args += modules

        properties = options[:properties] ? options[:properties].dup : {}
        properties['gwt.persistentunitcache'] = 'true'
        properties['gwt.persistentunitcachedir'] = unit_cache_dir

        Java::Commands.java 'com.google.gwt.dev.Compiler', *(args + [{:classpath => cp, :properties => properties, :java_args => options[:java_args], :pathing_jar => false}])
      end

      def superdev_dependencies(version = nil)
        self.dependencies + ["com.google.gwt:gwt-codeserver:jar:#{version || self.version}"]
      end

      def gwt_superdev(module_name, source_artifacts, work_dir, options = {})

        cp = Buildr.artifacts(self.superdev_dependencies(options[:version])).each(&:invoke).map(&:to_s) + Buildr.artifacts(source_artifacts).each(&:invoke).map(&:to_s)

        args = []
        args << '-port' << (options[:port] || 5050).to_s
        args << '-workDir' << work_dir
        (options[:src] || []).each do |src|
          args << '-src' << src
        end
        args << module_name

        properties = options[:properties] ? options[:properties].dup : {}

        java_args = options[:java_args] ? options[:java_args].dup : {}

        Java::Commands.java 'com.google.gwt.dev.codeserver.CodeServer', *(args + [{:classpath => cp, :properties => properties, :java_args => java_args, :pathing_jar => false}])
      end

      def gwt_css2gss(filenames, options = {})
        cp = Buildr.artifacts(self.dependencies(options[:version])).each(&:invoke).map(&:to_s)
        properties = options[:properties] ? options[:properties].dup : {}
        java_args = options[:java_args] ? options[:java_args].dup : {}
        Java::Commands.java 'com.google.gwt.resources.converter.Css2Gss', *([filenames] + [{ :classpath => cp, :properties => properties, :java_args => java_args, :pathing_jar => false }])
      end
    end

    module ProjectExtension
      include Extension

      first_time do
        desc 'Run C22 to GSS converter. Set css files via environment variable CSS_FILES'
        task('css2gss') do
          raise 'Please specify css files or directory via variable CSS_FILES' unless ENV['CSS_FILES']
          Buildr::GWT.gwt_css2gss(ENV['CSS_FILES'].to_s.split(' '))
        end
      end

      def gwt(module_names, options = {})
        p = options[:target_project]
        target_project = p.nil? ? project : p.is_a?(String) ? project(p) : p
        output_key = options[:output_key] || project.id
        output_dir = project._(:target, :generated, :gwt, output_key)
        artifacts = ([project.compile.target] + project.compile.sources + project.resources.sources).flatten.compact.collect do |a|
          a.is_a?(String) ? file(a) : a
        end
        dependencies = options[:dependencies] ? artifacts(options[:dependencies]) : (project.compile.dependencies + [project.compile.target]).flatten.compact.collect do |dep|
          dep.is_a?(String) ? file(dep) : dep
        end

        unit_cache_dir = project._(:target, :gwt, :unit_cache_dir, output_key)

        version = gwt_detect_version(dependencies) || Buildr::GWT.version

        additional_gwt_deps = []
        existing_deps = project.compile.dependencies.collect do |d|
          a = artifact(d)
          a.invoke if a.is_a?(Buildr::Artifact)
          a.to_s
        end
        Buildr::GWT.dependencies(version).each do |d|
          a = artifact(d)
          a.invoke if a.respond_to?(:invoke)
          unless options[:skip_merge_gwt_dependencies]
            project.iml.main_dependencies << a unless !project.iml? || existing_deps.include?(a.to_s)
            project.compile.dependencies << a unless existing_deps.include?(a.to_s)
          end
          additional_gwt_deps << a
        end

        task = project.file(output_dir) do
          Buildr::GWT.gwtc_main(module_names,
                                (dependencies + artifacts + additional_gwt_deps).flatten.compact,
                                output_dir,
                                unit_cache_dir,
                                {:version => version}.merge(options))
        end
        task.enhance(dependencies)
        task.enhance([project.compile])
        target_project.assets.paths << task
        task
      end

      def gwt_superdev_runner(module_name, options = {})

        dependencies = []
        if options[:dependencies]
          dependencies = artifacts(options[:dependencies])
        else
          sources = [] + project.compile.sources + project.resources.sources
          classes = [] + project.compile.dependencies + [project.compile.target]
          dependencies = (classes + sources).collect do |dep|
            dep.is_a?(String) ? file(dep) : dep
          end
        end

        desc 'Run Superdev mode'
        project.task('superdev') do
          work_dir = project._(:target, :gwt, :superdev)
          mkdir_p work_dir
          Buildr::GWT.gwt_superdev(module_name,
                                   dependencies,
                                   work_dir,
                                   {:version => gwt_detect_version(dependencies)}.merge(options))
        end
      end

      protected

      def gwt_detect_version(dependencies)
        version = nil
        dependencies.each do |dep|
          if dep.respond_to?(:to_spec_hash)
            hash = dep.to_spec_hash
            if %w(org.realityforge.com.google.gwt com.google.gwt).include?(hash[:group]) && 'gwt-user' == hash[:id] && :jar == hash[:type]
              version = hash[:version]
            end
          end
        end
        version
      end
    end
  end
end

class Buildr::Project
  include Buildr::GWT::ProjectExtension
end
