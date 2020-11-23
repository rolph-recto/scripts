#!/usr/bin/env python3

import sys
from bs4 import BeautifulSoup
import re

loc_pattern = r"Location (\d+)"
page_pattern = r"Page (\d+)"

def main():
  txt = sys.stdin.read()
  soup = BeautifulSoup(txt, "html.parser")
  headers = list(filter(lambda div: "Highlight" in div.contents[0], soup.find_all("div")))

  for header in headers:
    infostring = header.contents[2]

    for pattern in [loc_pattern, page_pattern]:
      res = re.search(pattern, infostring)
      if res is not None:
        info = res.group(1)
        print("### ", info, header.nextSibling.nextSibling.string)
        break


if __name__ == "__main__":
  main()
