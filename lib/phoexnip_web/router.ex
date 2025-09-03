defmodule PhoexnipWeb.Router do
  use PhoexnipWeb, :router

  import PhoexnipWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => "*"}
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json", "pdf"]
    plug PhoexnipWeb.Plugs.ApiKeyAuth
  end

  pipeline :login do
    plug :accepts, ["json"]
  end

  pipeline :browser_root_layout do
    plug :put_root_layout, html: {PhoexnipWeb.Layouts, :root}
  end

  # API routes
  scope "/api", PhoexnipWeb do
    pipe_through :api

    scope "/v1" do
      scope "/organisation_information" do
        get "/", OrganisationInformationController, :index
        post "/", OrganisationInformationController, :create
        put "/", OrganisationInformationController, :update
      end

      scope "/users" do
        resources "/", UserController, except: [:new, :edit]
        get "/:id/permissions", UserController, :user_access
        post "/:id/image", UserController, :image
        delete "/:id/image", UserController, :delete_image
        put "/:id/updatepassword", UserController, :update_password
      end

      resources "/roles", RolesController, except: [:new, :edit]
      get "/sitemap", SitemapController, :index

      scope "/master_data" do
        resources "/currencies", MasterDataCurrenciesController, except: [:new, :edit]
      end
    end
  end

  # API login
  scope "/api", PhoexnipWeb do
    pipe_through :login

    scope "/v1" do
      scope "/users" do
        post "/login", UserController, :login
        post "/refreshtoken/", UserController, :refreshtoken
      end
    end
  end

  # Swagger UI
  def swagger_info do
    host = Application.get_env(:phoexnip, :swagger_host)

    %{
      info: %{
        version: "1.0",
        title: "Phoexnip API"
      },
      host: host,
      securityDefinitions: %{
        api_key: %{
          type: "apiKey",
          name: "x-api-key",
          in: "header"
        }
      }
    }
  end

  scope "/api/v1/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :phoexnip, swagger_file: "swagger.json"
  end

  scope "/", PhoexnipWeb do
    pipe_through [:browser, :require_authenticated_user, :browser_root_layout]
  end

  # Dev helpers
  if Application.compile_env(:phoexnip, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: PhoexnipWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes
  scope "/", PhoexnipWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated, :browser_root_layout]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{PhoexnipWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      post "/log_in", UserSessionController, :create
      live "/log_in", UserLoginLive, :new
      live "/account/reset_password", UserForgotPasswordLive, :new
      live "/account/reset_password/:token", UserResetPasswordLive, :edit
    end
  end

  scope "/", PhoexnipWeb do
    pipe_through [:browser, :browser_root_layout]

    live_session :mount_user,
      on_mount: [{PhoexnipWeb.UserAuth, :mount_current_user}, PhoexnipWeb.PresenceTracker] do
      live "/",
           Home.Index,
           :index
    end
  end

  # Authenticated pages
  scope "/", PhoexnipWeb do
    pipe_through [:browser, :require_authenticated_user, :browser_root_layout]

    live_session :require_authenticated_user,
      on_mount: [{PhoexnipWeb.UserAuth, :ensure_authenticated}, PhoexnipWeb.PresenceTracker] do
      live "/account/settings", UserSettingsLive, :edit
      live "/account/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      scope "/organisation_information" do
        live "/", OrganisationInfoLive.New, :new
        live "/user_manual", OrganisationInfoLive.UserManual, :index
      end

      scope "/users" do
        live "/", UsersLive.Index, :index
        live "/new", UsersLive.New, :new
        live "/user_manual", UsersLive.UserManual, :index
        live "/:id/edit", UsersLive.New, :edit
        live "/:id", UsersLive.Show, :show
      end

      scope "/roles" do
        live "/", RolesLive.Index, :index
        live "/new", RolesLive.New, :new
        live "/user_manual", RolesLive.UserManual, :index
        live "/:id/edit", RolesLive.New, :edit
      end

      scope "/settings_reports" do
        live "/", SettingsReports.Index, :index
        scope "/user_login_report" do
          live "/", UsersLoginReport.Index, :index
        end
      end

      live "/schedulers", SchedulersLive.Index, :index

      scope "/master_data" do
        live "/", MasterDataIndexLive.Index, :index

        scope "/currencies" do
          live "/", MasterDataCurrenciesLive.Index, :index
          live "/new", MasterDataCurrenciesLive.Index, :new
          live "/usermanual", MasterDataCurrenciesLive.UserManual, :index
          live "/:id/edit", MasterDataCurrenciesLive.Index, :edit
        end

        scope "/groups" do
          live "/", MasterDataGroupsLive.Index, :index
          live "/new", MasterDataGroupsLive.Index, :new
          live "/usermanual", MasterDataGroupsLive.UserManual, :index
          live "/:id/edit", MasterDataGroupsLive.Index, :edit
        end
      end
    end
  end

  # Session/logout
  scope "/", PhoexnipWeb do
    pipe_through [:browser, :browser_root_layout]
    delete "/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{PhoexnipWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
