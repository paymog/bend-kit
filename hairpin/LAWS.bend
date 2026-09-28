import Base
import ./hairpin.bend as Hairpin
import bend-kit-http@0.23.0.0/http.bend as Http

def hs(k: String, v: String) -> Map<&2, List<&2, String>>:
  Http.set(Http.empty(), k, v)

# With no base, the URL goes as given, even when it is not absolute.
law target_no_base:
  {Hairpin.target("", "https://a.example/x") == Some{"https://a.example/x"} : Maybe<&2, String>}

law target_relative:
  {Hairpin.target("https://api.example/v1/", "users/7") == Some{"https://api.example/v1/users/7"} : Maybe<&2, String>}

law target_absolute_ref:
  {Hairpin.target("https://api.example/v1/", "http://b.example/y") == Some{"http://b.example/y"} : Maybe<&2, String>}

law target_bad_base:
  {Hairpin.target("/v1/", "users") == None{} : Maybe<&2, String>}

law merge_default:
  {Http.header(Hairpin.merge(hs("Accept", "a"), Http.empty()), "accept") == "a" : String}

# A request header replaces the default of its name, whatever the case of either.
law merge_override:
  {Http.fields(Hairpin.merge(hs("accept", "a"), hs("ACCEPT", "b")), "accept") == ["b"] : List<&2, String>}

law merge_both:
  {Http.header(Hairpin.merge(hs("x-a", "1"), hs("x-b", "2")), "x-a") == "1" : String}

# The client owns Host and Content-Length, so a default cannot set them.
law merge_reserved:
  {Http.fields(Hairpin.merge(hs("Host", "evil"), hs("content-length", "9")), "host") == Nil{} : List<&2, String>}
