interface DataSource {
  chartType: ChartType;
  chartOptions: ChartOptions;
  source: SourceEntity[];
}

export interface ChartOptions {
  xAxis:  {
    name: string;
    type: AxisType
  };
}

export interface SourceEntity {
  name?: string;
  // first element in array is xAxis, second - yAxis value
  data: [string, number][]
}

enum ChartType {
  "column",
  "line",
  "area"
}

enum AxisType {
  "value",
  "category",
  "time",
  "log"
}
