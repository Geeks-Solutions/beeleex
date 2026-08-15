defmodule BeeleexWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use BeeleexWeb, :controller
      use BeeleexWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: BeeleexWeb

      import Plug.Conn
      import BeeleexWeb.Gettext
      alias BeeleexWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/beeleex_web/templates",
        namespace: BeeleexWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      # The inner ("app") layout can be overridden by the host application so the
      # billing pages render inside its own chrome (nav/sidebar). Host sets, e.g.:
      #
      #     config :beeleex, :live_layout, {MyAppWeb.Layouts, :beeleex}
      #
      # The host layout function receives the page's assigns (including `@flash`
      # and anything assigned by an on_mount hook, e.g. `@current_user`) plus
      # `@inner_content`. Wrap the content in an element with class `beeleex` so
      # the shipped stylesheet applies.
      use Phoenix.LiveView,
        layout: Application.compile_env(:beeleex, :live_layout, {BeeleexWeb.Layouts, :live})

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import BeeleexWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import BeeleexWeb.ErrorHelpers
      import BeeleexWeb.Gettext
      alias BeeleexWeb.Router.Helpers, as: Routes
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components (table, pagination, modal, flash, inputs)
      import BeeleexWeb.BeeleeComponents

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      import BeeleexWeb.Gettext
      alias BeeleexWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
