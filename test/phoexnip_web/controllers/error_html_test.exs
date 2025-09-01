defmodule PhoexnipWeb.ErrorHTMLTest do
  use PhoexnipWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    rendered_html = render_to_string(PhoexnipWeb.ErrorHTML, "404", "html", [])

    # Assert that important parts of the page exist
    assert rendered_html =~ "404"
    assert rendered_html =~ "Me no see page, me no likey, me hit big stick!"
    assert rendered_html =~ "Back to safety!"
  end

  test "renders 500.html" do
    rendered_html = render_to_string(PhoexnipWeb.ErrorHTML, "500", "html", [])

    # Assert that important parts of the page exist
    assert rendered_html =~ "500 Spaghetti Error"
    assert rendered_html =~ "Oh no! Our spaghetti code is not working properly."
    assert rendered_html =~ "way back."
  end
end
