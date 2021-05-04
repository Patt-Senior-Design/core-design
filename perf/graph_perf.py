#!/usr/bin/env python3
import re
from pathlib import Path
import matplotlib.pyplot as plt
import matplotlib.lines as mlines

def get_test_stats (filename):
  file_path = Path(filename)
  table_stats = file_path.read_text().split('Table ')[1:]
  size_pattern = re.compile("^Size: (\d*)")
  lf_pattern = re.compile("LF: (\d*).*Avg Exec Time: (\d*)")#, Min: (\d*), Max: (\d*)")

  test_stats = {}
  table_sizes = []
  for table_str in table_stats:
    size_match = re.search(size_pattern, table_str)
    if not size_match:
      return False

    table_size = size_match[1];
    if table_size in table_sizes:
      print("Error: Repeats table size")
      return False
    table_sizes.append(table_size)

    time_data = re.findall(lf_pattern, table_str)
    for time_stats in time_data:
      lf = time_stats[0]
      if lf not in test_stats:
        test_stats[lf] = []
      test_stats[lf].append(float(time_stats[1]))

  return test_stats, table_sizes

def graph_stats(filename, it):
  plt.figure(figsize=(8.8, 6.6))
  normal_stats, normal_tables = get_test_stats('stats/{}-{}.out'.format(filename, it))
  ext_stats, ext_tables = get_test_stats('stats/fast{}-{}.out'.format(filename, it))
  if not normal_stats or not ext_stats:
    return False

  colors = []
  for (lf1, n_data), (lf2, e_data) in zip(normal_stats.items(), ext_stats.items()):
    p = plt.plot(normal_tables, n_data, '--', linewidth=1.1, label = "LF: {}".format(lf1))
    colors.append(p[-1].get_color())
    plt.plot(ext_tables, e_data, '-', c=colors[-1], linewidth=1.4, label = "LF: {}".format(lf2))

  plt.xlabel("Table Sizes")
  plt.ylabel('Average Execution Time')
  plt.yscale("log", base=2)
  plt.title('Hashset Performance Chart')

  ymin, ymax = plt.ylim()
  plt.ylim(ymin, ymax + 10000)
  i = 0
  patches = []
  for (lf1, n_data) in normal_stats.items():
    patches.append(mlines.Line2D([], [], color=colors[i],  label='LF: {}'.format(lf1)))
    i = i + 1
  n_line = mlines.Line2D([], [], linestyle='--', color='black', label='Normal')
  e_line = mlines.Line2D([], [], linestyle='-', color='black', label='Extension')
  first_leg = plt.legend(loc=1, ncol=1, prop={'size': 10}, handles=[*patches])
  ax = plt.gca().add_artist(first_leg)
  plt.legend(loc=2, ncol=1,prop={'size': 11}, handles=[n_line, e_line])
  plt.savefig("hashset_perf_{}.png".format(it), dpi=100)
  return True

if __name__ == '__main__':
  for i in range(2):
    if (graph_stats("hash-dram", i+1)):
      print ("Success")
    else:
      print ("Failure")

