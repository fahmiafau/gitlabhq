<script>
import { omit, throttle } from 'lodash';
import { GlLink, GlButton, GlTooltip, GlResizeObserverDirective } from '@gitlab/ui';
import { GlAreaChart, GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/dist/charts';
import dateFormat from 'dateformat';
import { s__, __ } from '~/locale';
import { getSvgIconPathContent } from '~/lib/utils/icon_utils';
import Icon from '~/vue_shared/components/icon.vue';
import {
  chartHeight,
  graphTypes,
  lineTypes,
  lineWidths,
  symbolSizes,
  dateFormats,
} from '../../constants';
import { getYAxisOptions, getChartGrid, getTooltipFormatter } from './options';
import { makeDataSeries } from '~/helpers/monitor_helper';
import { graphDataValidatorForValues } from '../../utils';

/**
 * A "virtual" coordinates system for the deployment icons.
 * Deployment icons are displayed along the [min, max]
 * range at height `pos`.
 */
const deploymentYAxisCoords = {
  min: 0,
  pos: 3, // 3% height of chart's grid
  max: 100,
};

const THROTTLED_DATAZOOM_WAIT = 1000; // milliseconds
const timestampToISODate = timestamp => new Date(timestamp).toISOString();

const events = {
  datazoom: 'datazoom',
};

export default {
  components: {
    GlAreaChart,
    GlLineChart,
    GlTooltip,
    GlButton,
    GlChartSeriesLabel,
    GlLink,
    Icon,
  },
  directives: {
    GlResizeObserverDirective,
  },
  inheritAttrs: false,
  props: {
    graphData: {
      type: Object,
      required: true,
      validator: graphDataValidatorForValues.bind(null, false),
    },
    option: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    seriesConfig: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    deploymentData: {
      type: Array,
      required: false,
      default: () => [],
    },
    projectPath: {
      type: String,
      required: false,
      default: '',
    },
    singleEmbed: {
      type: Boolean,
      required: false,
      default: false,
    },
    thresholds: {
      type: Array,
      required: false,
      default: () => [],
    },
    legendAverageText: {
      type: String,
      required: false,
      default: s__('Metrics|Avg'),
    },
    legendMaxText: {
      type: String,
      required: false,
      default: s__('Metrics|Max'),
    },
    groupId: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      tooltip: {
        title: '',
        content: [],
        commitUrl: '',
        isDeployment: false,
        sha: '',
      },
      width: 0,
      height: chartHeight,
      svgs: {},
      primaryColor: null,
      throttledDatazoom: null,
    };
  },
  computed: {
    chartData() {
      // Transforms & supplements query data to render appropriate labels & styles
      // Input: [{ queryAttributes1 }, { queryAttributes2 }]
      // Output: [{ seriesAttributes1 }, { seriesAttributes2 }]
      return this.graphData.metrics.reduce((acc, query) => {
        const { appearance } = query;
        const lineType =
          appearance && appearance.line && appearance.line.type
            ? appearance.line.type
            : lineTypes.default;
        const lineWidth =
          appearance && appearance.line && appearance.line.width
            ? appearance.line.width
            : lineWidths.default;
        const areaStyle = {
          opacity:
            appearance && appearance.area && typeof appearance.area.opacity === 'number'
              ? appearance.area.opacity
              : undefined,
        };
        const series = makeDataSeries(query.result || [], {
          name: this.formatLegendLabel(query),
          lineStyle: {
            type: lineType,
            width: lineWidth,
          },
          showSymbol: false,
          areaStyle: this.graphData.type === 'area-chart' ? areaStyle : undefined,
          ...this.seriesConfig,
        });

        return acc.concat(series);
      }, []);
    },
    chartOptionSeries() {
      return (this.option.series || []).concat(
        this.deploymentSeries ? [this.deploymentSeries] : [],
      );
    },
    chartOptions() {
      const { yAxis, xAxis } = this.option;
      const option = omit(this.option, ['series', 'yAxis', 'xAxis']);

      const dataYAxis = {
        ...getYAxisOptions(this.graphData.yAxis),
        ...yAxis,
      };

      const deploymentsYAxis = {
        show: false,
        min: deploymentYAxisCoords.min,
        max: deploymentYAxisCoords.max,
        axisLabel: {
          // formatter fn required to trigger tooltip re-positioning
          formatter: () => {},
        },
      };

      const timeXAxis = {
        name: __('Time'),
        type: 'time',
        axisLabel: {
          formatter: date => dateFormat(date, dateFormats.timeOfDay),
        },
        axisPointer: {
          snap: true,
        },
        ...xAxis,
      };

      return {
        series: this.chartOptionSeries,
        xAxis: timeXAxis,
        yAxis: [dataYAxis, deploymentsYAxis],
        grid: getChartGrid(),
        dataZoom: [this.dataZoomConfig],
        ...option,
      };
    },
    dataZoomConfig() {
      const handleIcon = this.svgs['scroll-handle'];

      return handleIcon ? { handleIcon } : {};
    },
    /**
     * This method returns the earliest time value in all series of a chart.
     * Takes a chart data with data to populate a timeseries.
     * data should be an array of data points [t, y] where t is a ISO formatted date,
     * and is sorted by t (time).
     * @returns {(String|null)} earliest x value from all series, or null when the
     * chart series data is empty.
     */
    earliestDatapoint() {
      return this.chartData.reduce((acc, series) => {
        const { data } = series;
        const { length } = data;
        if (!length) {
          return acc;
        }

        const [first] = data[0];
        const [last] = data[length - 1];
        const seriesEarliest = first < last ? first : last;

        return seriesEarliest < acc || acc === null ? seriesEarliest : acc;
      }, null);
    },
    glChartComponent() {
      const chartTypes = {
        'area-chart': GlAreaChart,
        'line-chart': GlLineChart,
      };
      return chartTypes[this.graphData.type] || GlAreaChart;
    },
    isMultiSeries() {
      return this.tooltip.content.length > 1;
    },
    recentDeployments() {
      return this.deploymentData.reduce((acc, deployment) => {
        if (deployment.created_at >= this.earliestDatapoint) {
          const { id, created_at, sha, ref, tag } = deployment;
          acc.push({
            id,
            createdAt: created_at,
            sha,
            commitUrl: `${this.projectPath}/-/commit/${sha}`,
            tag,
            tagUrl: tag ? `${this.tagsPath}/${ref.name}` : null,
            ref: ref.name,
            showDeploymentFlag: false,
          });
        }

        return acc;
      }, []);
    },
    deploymentSeries() {
      return {
        type: graphTypes.deploymentData,

        yAxisIndex: 1, // deploymentsYAxis index
        data: this.recentDeployments.map(deployment => [
          deployment.createdAt,
          deploymentYAxisCoords.pos,
        ]),

        symbol: this.svgs.rocket,
        symbolSize: symbolSizes.default,
        itemStyle: {
          color: this.primaryColor,
        },
      };
    },
    tooltipYFormatter() {
      // Use same format as y-axis
      return getTooltipFormatter({ format: this.graphData.yAxis?.format });
    },
  },
  created() {
    this.setSvg('rocket');
    this.setSvg('scroll-handle');
  },
  destroyed() {
    if (this.throttledDatazoom) {
      this.throttledDatazoom.cancel();
    }
  },
  methods: {
    formatLegendLabel(query) {
      return `${query.label}`;
    },
    formatTooltipText(params) {
      this.tooltip.title = dateFormat(params.value, dateFormats.default);
      this.tooltip.content = [];

      params.seriesData.forEach(dataPoint => {
        if (dataPoint.value) {
          const [xVal, yVal] = dataPoint.value;
          this.tooltip.isDeployment = dataPoint.componentSubType === graphTypes.deploymentData;
          if (this.tooltip.isDeployment) {
            const [deploy] = this.recentDeployments.filter(
              deployment => deployment.createdAt === xVal,
            );
            this.tooltip.sha = deploy.sha.substring(0, 8);
            this.tooltip.commitUrl = deploy.commitUrl;
          } else {
            const { seriesName, color, dataIndex } = dataPoint;

            this.tooltip.content.push({
              name: seriesName,
              dataIndex,
              value: this.tooltipYFormatter(yVal),
              color,
            });
          }
        }
      });
    },
    setSvg(name) {
      getSvgIconPathContent(name)
        .then(path => {
          if (path) {
            this.$set(this.svgs, name, `path://${path}`);
          }
        })
        .catch(e => {
          // eslint-disable-next-line no-console, @gitlab/require-i18n-strings
          console.error('SVG could not be rendered correctly: ', e);
        });
    },
    onChartUpdated(eChart) {
      [this.primaryColor] = eChart.getOption().color;
    },

    onChartCreated(eChart) {
      // Emit a datazoom event that corresponds to the eChart
      // `datazoom` event.

      if (this.throttledDatazoom) {
        // Chart can be created multiple times in this component's
        // lifetime, remove previous handlers every time
        // chart is created.
        this.throttledDatazoom.cancel();
      }

      // Emitting is throttled to avoid flurries of calls when
      // the user changes or scrolls the zoom bar.
      this.throttledDatazoom = throttle(
        () => {
          const { startValue, endValue } = eChart.getOption().dataZoom[0];
          this.$emit(events.datazoom, {
            start: timestampToISODate(startValue),
            end: timestampToISODate(endValue),
          });
        },
        THROTTLED_DATAZOOM_WAIT,
        {
          leading: false,
        },
      );

      eChart.off('datazoom');
      eChart.on('datazoom', this.throttledDatazoom);
    },
    onResize() {
      if (!this.$refs.chart) return;
      const { width } = this.$refs.chart.$el.getBoundingClientRect();
      this.width = width;
    },
  },
};
</script>

<template>
  <div v-gl-resize-observer-directive="onResize">
    <component
      :is="glChartComponent"
      ref="chart"
      v-bind="$attrs"
      :group-id="groupId"
      :data="chartData"
      :option="chartOptions"
      :format-tooltip-text="formatTooltipText"
      :thresholds="thresholds"
      :width="width"
      :height="height"
      :average-text="legendAverageText"
      :max-text="legendMaxText"
      @created="onChartCreated"
      @updated="onChartUpdated"
    >
      <template v-if="tooltip.isDeployment">
        <template slot="tooltipTitle">
          {{ __('Deployed') }}
        </template>
        <div slot="tooltipContent" class="d-flex align-items-center">
          <icon name="commit" class="mr-2" />
          <gl-link :href="tooltip.commitUrl">{{ tooltip.sha }}</gl-link>
        </div>
      </template>
      <template v-else>
        <template slot="tooltipTitle">
          <slot name="tooltipTitle">
            <div class="text-nowrap">
              {{ tooltip.title }}
            </div>
          </slot>
        </template>
        <template slot="tooltipContent">
          <slot name="tooltipContent" :tooltip="tooltip">
            <div
              v-for="(content, key) in tooltip.content"
              :key="key"
              class="d-flex justify-content-between"
            >
              <gl-chart-series-label :color="isMultiSeries ? content.color : ''">
                {{ content.name }}
              </gl-chart-series-label>
              <div class="prepend-left-32">
                {{ content.value }}
              </div>
            </div>
          </slot>
        </template>
      </template>
    </component>
  </div>
</template>
