import json
import re
import unittest
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data/landmarks.json"
SOURCES = ROOT / "docs/landmark-sources.md"
ROUTE = {
    "wuwei": {"leitai", "wenmiao", "tiantishan"},
    "zhangye": {"danxia", "matisi", "dafosi"},
    "jiuquan": {"jiuquan_spring", "drum_tower", "poplar"},
    "jiayuguan": {"jiayu_fort", "hanging_wall", "first_beacon"},
    "guazhou": {"yulin", "suoyang", "shuangta"},
    "dunhuang": {"crescent", "mogao", "yardang", "yumen"},
}
PROFILES = set("desert rock water garden forest architecture cliff ruin".split())
KINDS = set("trace pair turn echo uncover order".split())
MOTIFS = set(
    "camel water sand horse roof arch lotus ribbon cloud star leaf reed rock brick "
    "bell tower bird wave sun snow".split()
)


class LandmarkCatalogTest(unittest.TestCase):
    def setUp(self):
        self.assertTrue(CATALOG.is_file(), "六站导览尚无可加载的景点数据")
        self.sites = json.loads(CATALOG.read_text(encoding="utf-8"))["sites"]

    def test_all_destinations_belong_to_their_map_station(self):
        self.assertCountEqual([site["id"] for site in self.sites], set.union(*ROUTE.values()))
        for station, expected in ROUTE.items():
            with self.subTest(station=station):
                self.assertEqual({s["id"] for s in self.sites if s["station"] == station}, expected)

    def test_visit_text_changes_at_each_season_and_time(self):
        encountered = set()
        for site in self.sites:
            with self.subTest(site=site["id"]):
                self.assertTrue(site["name"].strip())
                self.assertTrue(1 <= len(site["short"]) <= 7)
                self.assertIn(site["profile"], PROFILES)
                self.assertGreaterEqual(len(re.findall(r"[。！？]", site["intro"])), 2)
                self.assertEqual(set(site["seasons"]), {"spring", "summer", "autumn", "winter"})
                self.assertEqual(set(site["times"]), {"dawn", "day", "dusk", "night"})
                for text in (*site["seasons"].values(), *site["times"].values()):
                    self.assertRegex(text, r"[\u4e00-\u9fff]")
                    self.assertNotIn(text, encountered, "观察需要说出这个地点的变化")
                    encountered.add(text)

    def test_every_site_has_three_accessible_distinct_picture_targets(self):
        kinds_by_station = {station: set() for station in ROUTE}
        for site in self.sites:
            with self.subTest(site=site["id"]):
                details = site["details"]
                self.assertEqual(len(details), 3)
                self.assertEqual(len({d["id"] for d in details}), 3)
                xs = sorted(d["x"] for d in details)
                self.assertTrue(0.1 <= xs[0] and xs[-1] <= 0.9)
                self.assertTrue(all(b - a >= 0.18 for a, b in zip(xs, xs[1:])))
                for detail in details:
                    self.assertRegex(detail["id"], r"^[a-z][a-z0-9_]*$")
                    self.assertTrue(0.32 <= detail["y"] <= 0.68)
                    self.assertTrue(2 <= len(detail["title"]) <= 5)
                    self.assertIn(detail["motif"], MOTIFS)
                    self.assertIn(detail["kind"], KINDS)
                    kinds_by_station[site["station"]].add(detail["kind"])
                    self.assertEqual(len(detail["pieces"]), 3)
                    self.assertEqual(len(set(detail["pieces"])), 3)
                    for piece in detail["pieces"]:
                        self.assertRegex(piece, r"^[\u4e00-\u9fff]{1,4}$")
                    self.assertTrue(detail["instruction"].strip())
                    self.assertTrue(detail["result"].strip())
        for station, kinds in kinds_by_station.items():
            with self.subTest(station=station):
                self.assertGreaterEqual(len(kinds), 2)
        self.assertEqual(set.union(*kinds_by_station.values()), KINDS)

    def test_each_offline_entry_can_be_traced_to_a_documented_source(self):
        self.assertTrue(SOURCES.is_file(), "家长和编辑需要逐处可核对的资料索引")
        bibliography = SOURCES.read_text(encoding="utf-8")
        for site in self.sites:
            with self.subTest(site=site["id"]):
                link = urlsplit(site["source"])
                self.assertRegex(site.get("sourceName", ""), r"[\u4e00-\u9fff]", "资料入口缺少可读的来源名称")
                self.assertIn(link.scheme, {"http", "https"})
                self.assertTrue(link.hostname)
                self.assertNotEqual(link.path.strip("/"), "")
                self.assertIn(site["name"], bibliography)
                self.assertIn(site["source"], bibliography)

    def test_each_sketch_commission_opens_two_valid_views_and_a_local_detail(self):
        for site in self.sites:
            with self.subTest(site=site["id"]):
                self.assertIn("fieldwork", site, "该地点缺少可以实际完成的写生委托")
                task = site["fieldwork"]
                self.assertTrue(1 <= len(task["title"]) <= 7)
                self.assertTrue(task["note"].strip())
                self.assertEqual(len(task["views"]), 2)
                self.assertEqual(len(set(task["views"])), 2)
                for view in task["views"]:
                    season, phase = view.split(":")
                    self.assertIn(season, site["seasons"])
                    self.assertIn(phase, site["times"])
                self.assertIn(task["detail"], {d["id"] for d in site["details"]})


if __name__ == "__main__":
    unittest.main()
