module Ci
  class BuildsController < Ci::ApplicationController
    before_action :authenticate_user!, except: [:status]
    before_action :project
    before_action :authorize_access_project!, except: [:status]
    before_action :authorize_manage_project!, except: [:status, :retry, :cancel]
    before_action :authorize_manage_builds!, only: [:retry, :cancel]
    before_action :build

    def retry
      if @build.commands.blank?
        return page_404
      end

      build = Ci::Build.retry(@build)

      if params[:return_to]
        redirect_to URI.parse(params[:return_to]).path
      else
        redirect_to ci_project_build_path(project, build)
      end
    end

    def status
      render json: @build.to_json(only: [:status, :id, :sha, :coverage], methods: :sha)
    end

    def cancel
      @build.cancel

      redirect_to ci_project_build_path(@project, @build)
    end

    protected

    def project
      @project = Ci::Project.find(params[:project_id])
    end

    def build
      @build ||= project.builds.unscoped.find_by!(id: params[:id])
    end

    def commit_by_sha
      @project.commits.find_by(sha: params[:id])
    end
  end
end
