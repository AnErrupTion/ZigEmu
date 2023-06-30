pub const Architecture = enum {
    amd64,
};

pub const Chipset = enum {
    i440fx,
    q35,
};

pub const UsbType = enum {
    none,
    ohci,
    uhci,
    ehci,
    xhci,
};

pub const Cpu = enum {
    host,
    max,
};

pub const NetworkType = enum {
    none,
    nat,
};

pub const Interface = enum {
    rtl8139,
    e1000,
    e1000e,
    vmware,
    usb,
    virtio,
};

pub const Display = enum {
    none,
    sdl,
    gtk,
    spice,
};

pub const Gpu = enum {
    none,
    vga,
    qxl,
    vmware,
    virtio,
};

pub const HostDevice = enum {
    none,
    alsa,
    pulseaudio,
};

pub const Sound = enum {
    sb16,
    ac97,
    ich6,
    ich9,
    usb,
};

pub const Keyboard = enum {
    none,
    usb,
    virtio,
};

pub const Mouse = enum {
    none,
    usb,
    virtio,
};

pub const DriveBus = enum {
    usb,
    ide,
    sata,
    virtio,
};

pub const DriveFormat = enum {
    raw,
    qcow2,
    vmdk,
    vdi,
    vhd,
};

pub const DriveCache = enum {
    none,
    writeback,
    writethrough,
    directsync,
    unsafe,
};

pub const Drive = struct {
    is_cdrom: bool,
    bus: DriveBus,
    format: DriveFormat,
    cache: DriveCache,
    is_ssd: bool,
    path: []const u8,
};

// TODO: "removable" drive type
// TODO: Controllers? (more modular)
// TODO: PCI/USB host devices
pub const VirtualMachine = struct {
    basic: struct {
        name: []const u8,
        architecture: Architecture,
        has_acceleration: bool,
        chipset: Chipset,
        usb_type: UsbType,
        has_ahci: bool,
    },
    memory: struct {
        ram: u64,
    },
    processor: struct {
        cpu: Cpu,
        features: []const u8,
        cores: u64,
        threads: u64,
    },
    network: struct {
        type: NetworkType,
        interface: Interface,
    },
    graphics: struct {
        display: Display,
        gpu: Gpu,
        has_vga_emulation: bool,
        has_graphics_acceleration: bool,
    },
    audio: struct {
        host_device: HostDevice,
        sound: Sound,
        has_input: bool,
        has_output: bool,
    },
    peripherals: struct {
        keyboard: Keyboard,
        mouse: Mouse,
        has_mouse_absolute_pointing: bool,
    },
    // TODO: This is horrible, we need to find a way to have an infinite number of drives
    drive0: Drive,
    drive1: Drive,
    drive2: Drive,
    drive3: Drive,
    drive4: Drive,
};
