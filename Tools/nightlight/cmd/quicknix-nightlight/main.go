package main

import (
	"bytes"
	"encoding/binary"
	"flag"
	"fmt"
	"math"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_gamma_control"
	wlclient "github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
	"golang.org/x/sys/unix"
)

type gammaRamp struct {
	red   []uint16
	green []uint16
	blue  []uint16
}

type rgb struct {
	r float64
	g float64
	b float64
}

type xyz struct {
	x float64
	y float64
	z float64
}

type outputControl struct {
	output  *wlclient.Output
	control *wlr_gamma_control.ZwlrGammaControlV1
	size    uint32
	name    string
	failed  bool
}

func main() {
	temp := flag.Int("temperature", 4000, "color temperature in Kelvin")
	gamma := flag.Float64("gamma", 1.0, "gamma correction")
	once := flag.Bool("once", false, "apply once and exit")
	flag.Parse()

	if *temp < 1000 || *temp > 10000 {
		fatalf("temperature must be between 1000 and 10000K")
	}
	if *gamma <= 0 || *gamma > 10 {
		fatalf("gamma must be between 0 and 10")
	}

	display, err := wlclient.Connect("")
	if err != nil {
		fatalf("connect to Wayland: %v", err)
	}
	defer display.Context().Close()

	controls, err := setupControls(display, *temp, *gamma)
	if err != nil {
		fatalf("%v", err)
	}
	defer destroyControls(controls)

	deadline := time.Now().Add(3 * time.Second)
	for {
		allReady := true
		for _, control := range controls {
			if !control.failed && control.size == 0 {
				allReady = false
				break
			}
		}
		if allReady {
			break
		}
		if time.Now().After(deadline) {
			fatalf("timed out waiting for gamma ramp sizes")
		}
		_ = display.Context().SetReadDeadline(time.Now().Add(200 * time.Millisecond))
		_ = display.Context().Dispatch()
	}
	_ = display.Context().SetReadDeadline(time.Time{})

	if err := applyTemperature(controls, *temp, *gamma); err != nil {
		fatalf("apply gamma: %v", err)
	}
	_ = display.Roundtrip()

	if *once {
		return
	}

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
	for {
		select {
		case <-signals:
			return
		default:
			if err := display.Context().Dispatch(); err != nil {
				fatalf("Wayland dispatch: %v", err)
			}
		}
	}
}

func setupControls(display *wlclient.Display, temp int, gamma float64) ([]*outputControl, error) {
	registry, err := display.GetRegistry()
	if err != nil {
		return nil, fmt.Errorf("get registry: %w", err)
	}

	var gammaManager *wlr_gamma_control.ZwlrGammaControlManagerV1
	outputs := []*wlclient.Output{}
	outputNames := map[uint32]string{}

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		switch e.Interface {
		case wlr_gamma_control.ZwlrGammaControlManagerV1InterfaceName:
			manager := wlr_gamma_control.NewZwlrGammaControlManagerV1(display.Context())
			version := e.Version
			if version > 1 {
				version = 1
			}
			if err := registry.Bind(e.Name, e.Interface, version, manager); err == nil {
				gammaManager = manager
			}
		case "wl_output":
			output := wlclient.NewOutput(display.Context())
			version := e.Version
			if version > 4 {
				version = 4
			}
			if err := registry.Bind(e.Name, e.Interface, version, output); err != nil {
				return
			}
			outputID := output.ID()
			output.SetNameHandler(func(ev wlclient.OutputNameEvent) {
				outputNames[outputID] = ev.Name
			})
			outputs = append(outputs, output)
		}
	})

	if err := display.Roundtrip(); err != nil {
		return nil, fmt.Errorf("registry roundtrip: %w", err)
	}
	if err := display.Roundtrip(); err != nil {
		return nil, fmt.Errorf("output roundtrip: %w", err)
	}
	if gammaManager == nil {
		return nil, fmt.Errorf("compositor does not expose %s", wlr_gamma_control.ZwlrGammaControlManagerV1InterfaceName)
	}

	controls := []*outputControl{}
	for _, output := range outputs {
		name := outputNames[output.ID()]
		if strings.HasPrefix(name, "HEADLESS-") {
			continue
		}
		control, err := gammaManager.GetGammaControl(output)
		if err != nil {
			continue
		}
		entry := &outputControl{
			output:  output,
			control: control,
			name:    name,
		}
		control.SetGammaSizeHandler(func(ev wlr_gamma_control.ZwlrGammaControlV1GammaSizeEvent) {
			entry.size = ev.Size
		})
		control.SetFailedHandler(func(_ wlr_gamma_control.ZwlrGammaControlV1FailedEvent) {
			entry.failed = true
		})
		controls = append(controls, entry)
	}

	if len(controls) == 0 {
		return nil, fmt.Errorf("no outputs accepted gamma control")
	}
	return controls, nil
}

func destroyControls(controls []*outputControl) {
	for _, control := range controls {
		if control.control != nil && !control.control.IsZombie() {
			_ = control.control.Destroy()
		}
	}
}

func applyTemperature(controls []*outputControl, temp int, gamma float64) error {
	applied := 0
	for _, control := range controls {
		if control.failed || control.size == 0 {
			continue
		}
		ramp := generateGammaRamp(control.size, temp, gamma)
		buf := bytes.NewBuffer(make([]byte, 0, int(control.size)*6))
		for _, value := range ramp.red {
			_ = binary.Write(buf, binary.LittleEndian, value)
		}
		for _, value := range ramp.green {
			_ = binary.Write(buf, binary.LittleEndian, value)
		}
		for _, value := range ramp.blue {
			_ = binary.Write(buf, binary.LittleEndian, value)
		}
		if err := setGammaBytes(control.control, buf.Bytes()); err != nil {
			return err
		}
		applied++
	}
	if applied == 0 {
		return fmt.Errorf("no active outputs with gamma ramp sizes")
	}
	return nil
}

func setGammaBytes(control *wlr_gamma_control.ZwlrGammaControlV1, data []byte) error {
	fd, err := unix.MemfdCreate("quicknix-gamma-ramp", 0)
	if err != nil {
		return err
	}
	defer unix.Close(fd)

	if err := unix.Ftruncate(fd, int64(len(data))); err != nil {
		return err
	}

	dupFd, err := unix.Dup(fd)
	if err != nil {
		return err
	}
	file := os.NewFile(uintptr(dupFd), "gamma")
	defer file.Close()

	if _, err := file.Write(data); err != nil {
		return err
	}
	if _, err := unix.Seek(fd, 0, 0); err != nil {
		return err
	}
	return control.SetGamma(fd)
}

func illuminantD(temp int) (float64, float64, bool) {
	var x float64
	switch {
	case temp >= 2500 && temp <= 7000:
		t := float64(temp)
		x = 0.244063 + 0.09911e3/t + 2.9678e6/(t*t) - 4.6070e9/(t*t*t)
	case temp > 7000 && temp <= 25000:
		t := float64(temp)
		x = 0.237040 + 0.24748e3/t + 1.9018e6/(t*t) - 2.0064e9/(t*t*t)
	default:
		return 0, 0, false
	}
	y := -3*(x*x) + 2.870*x - 0.275
	return x, y, true
}

func planckianLocus(temp int) (float64, float64, bool) {
	var x float64
	var y float64
	switch {
	case temp >= 1667 && temp <= 4000:
		t := float64(temp)
		x = -0.2661239e9/(t*t*t) - 0.2343589e6/(t*t) + 0.8776956e3/t + 0.179910
		if temp <= 2222 {
			y = -1.1063814*(x*x*x) - 1.34811020*(x*x) + 2.18555832*x - 0.20219683
		} else {
			y = -0.9549476*(x*x*x) - 1.37418593*(x*x) + 2.09137015*x - 0.16748867
		}
	case temp > 4000 && temp < 25000:
		t := float64(temp)
		x = -3.0258469e9/(t*t*t) + 2.1070379e6/(t*t) + 0.2226347e3/t + 0.240390
		y = 3.0817580*(x*x*x) - 5.87338670*(x*x) + 3.75112997*x - 0.37001483
	default:
		return 0, 0, false
	}
	return x, y, true
}

func srgbGamma(value float64, gamma float64) float64 {
	if value <= 0.0031308 {
		return 12.92 * value
	}
	return math.Pow(1.055*value, 1.0/gamma) - 0.055
}

func clamp01(value float64) float64 {
	switch {
	case value > 1:
		return 1
	case value < 0:
		return 0
	default:
		return value
	}
}

func xyzToSRGB(value xyz) rgb {
	return rgb{
		r: srgbGamma(clamp01(3.2404542*value.x-1.5371385*value.y-0.4985314*value.z), 2.2),
		g: srgbGamma(clamp01(-0.9692660*value.x+1.8760108*value.y+0.0415560*value.z), 2.2),
		b: srgbGamma(clamp01(0.0556434*value.x-0.2040259*value.y+1.0572252*value.z), 2.2),
	}
}

func normalizeRGB(value *rgb) {
	maxValue := math.Max(value.r, math.Max(value.g, value.b))
	if maxValue > 0 {
		value.r /= maxValue
		value.g /= maxValue
		value.b /= maxValue
	}
}

func calcWhitepoint(temp int) rgb {
	if temp == 6500 {
		return rgb{r: 1, g: 1, b: 1}
	}

	var whitepoint xyz
	switch {
	case temp >= 25000:
		x, y, _ := illuminantD(25000)
		whitepoint.x = x
		whitepoint.y = y
	case temp >= 4000:
		x, y, _ := illuminantD(temp)
		whitepoint.x = x
		whitepoint.y = y
	case temp >= 2500:
		x1, y1, _ := illuminantD(temp)
		x2, y2, _ := planckianLocus(temp)
		factor := float64(4000-temp) / 1500.0
		sineFactor := (math.Cos(math.Pi*factor) + 1) / 2
		whitepoint.x = x1*sineFactor + x2*(1-sineFactor)
		whitepoint.y = y1*sineFactor + y2*(1-sineFactor)
	default:
		t := temp
		if t < 1667 {
			t = 1667
		}
		x, y, _ := planckianLocus(t)
		whitepoint.x = x
		whitepoint.y = y
	}

	whitepoint.z = 1 - whitepoint.x - whitepoint.y
	whitepointRGB := xyzToSRGB(whitepoint)
	normalizeRGB(&whitepointRGB)
	return whitepointRGB
}

func generateGammaRamp(size uint32, temp int, gamma float64) gammaRamp {
	ramp := gammaRamp{
		red:   make([]uint16, size),
		green: make([]uint16, size),
		blue:  make([]uint16, size),
	}
	whitepoint := calcWhitepoint(temp)
	for i := uint32(0); i < size; i++ {
		value := float64(i) / float64(size-1)
		ramp.red[i] = uint16(clamp01(math.Pow(value*whitepoint.r, 1.0/gamma)) * 65535)
		ramp.green[i] = uint16(clamp01(math.Pow(value*whitepoint.g, 1.0/gamma)) * 65535)
		ramp.blue[i] = uint16(clamp01(math.Pow(value*whitepoint.b, 1.0/gamma)) * 65535)
	}
	return ramp
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "quicknix-nightlight: "+format+"\n", args...)
	os.Exit(1)
}
