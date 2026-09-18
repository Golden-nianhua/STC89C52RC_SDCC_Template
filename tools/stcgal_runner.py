# /// script
# requires-python = ">=3.11"
# dependencies = ["stcgal==1.10"]
# ///

"""Read the project TOML configuration and invoke stcgal."""

from __future__ import annotations

import argparse
import sys
import tomllib
from pathlib import Path
from typing import Any


SUPPORTED_PROTOCOLS = {"auto", "stc89", "stc89a"}
SUPPORTED_RESET_PINS = {"dtr", "rts"}
RESET_PIN_LABELS = {
    "dtr": "DTR 正向控制",
    "rts": "RTS 正向控制",
}
BOOLEAN_OPTION_MAP = (
    ("double_speed_6t", "cpu_6t_enabled"),
    ("watchdog_stop_requires_power_cycle", "watchdog_por_enabled"),
    ("internal_xram_enabled", "xram_enabled"),
    ("erase_eeprom_on_next_download", "eeprom_erase_enabled"),
    ("require_p1_0_p1_1_low_for_download", "bsl_pindetect_enabled"),
)
HARDWARE_OPTION_LABELS = (
    ("double_speed_6t", "系统速度采用 6T 双倍速模式"),
    ("reduce_oscillator_gain", "降低振荡器放大增益，使用 1/2 增益"),
    ("watchdog_stop_requires_power_cycle", "看门狗只有 MCU 断电后才停止"),
    ("internal_xram_enabled", "使用 MCU 内部扩展 RAM"),
    ("erase_eeprom_on_next_download", "下次下载时一并擦除用户 EEPROM"),
    ("require_p1_0_p1_1_low_for_download", "P1.0 和 P1.1 同时为低电平才可下载"),
    ("ale_as_p4_5", "ALE 脚作为 P4.5 口使用"),
)


def require_value(section: dict[str, Any], key: str, expected_type: type) -> Any:
    if key not in section:
        raise ValueError(f"missing required setting: {key}")
    value = section[key]
    if not isinstance(value, expected_type):
        raise ValueError(f"{key} must be {expected_type.__name__}")
    return value


def load_config(
    path: Path,
) -> tuple[list[str], list[str], dict[str, bool], dict[str, Any]]:
    with path.open("rb") as config_file:
        config = tomllib.load(config_file)

    connection = require_value(config, "connection", dict)
    options = require_value(config, "hardware_options", dict)

    port = require_value(connection, "port", str)
    protocol = require_value(connection, "protocol", str)
    handshake_baud = require_value(connection, "handshake_baud", int)
    transfer_baud = require_value(connection, "transfer_baud", int)
    auto_power_cycle = require_value(connection, "auto_power_cycle", bool)
    reset_pin = require_value(connection, "reset_pin", str)
    keep_dtr_inactive = require_value(connection, "keep_dtr_inactive", bool)

    if not port:
        raise ValueError("connection.port must not be empty")
    if protocol not in SUPPORTED_PROTOCOLS:
        raise ValueError(f"connection.protocol must be one of {sorted(SUPPORTED_PROTOCOLS)}")
    if handshake_baud <= 0 or transfer_baud <= 0:
        raise ValueError("baud rates must be positive integers")
    if reset_pin not in SUPPORTED_RESET_PINS:
        raise ValueError(f"connection.reset_pin must be one of {sorted(SUPPORTED_RESET_PINS)}")
    if keep_dtr_inactive and reset_pin != "rts":
        raise ValueError("connection.keep_dtr_inactive requires reset_pin = 'rts'")

    base_arguments = [
        "-P", protocol,
        "-p", port,
        "-l", str(handshake_baud),
        "-b", str(transfer_baud),
    ]
    if auto_power_cycle:
        base_arguments.extend(("-a", "-A", reset_pin))

    option_arguments: list[str] = []
    for config_key, stcgal_key in BOOLEAN_OPTION_MAP:
        value = require_value(options, config_key, bool)
        option_arguments.extend(("-o", f"{stcgal_key}={str(value).lower()}"))

    reduce_gain = require_value(options, "reduce_oscillator_gain", bool)
    clock_gain = "low" if reduce_gain else "high"
    option_arguments.extend(("-o", f"clock_gain={clock_gain}"))

    ale_as_p4_5 = require_value(options, "ale_as_p4_5", bool)
    ale_enabled = not ale_as_p4_5
    option_arguments.extend(("-o", f"ale_enabled={str(ale_enabled).lower()}"))

    hardware_options = {
        key: require_value(options, key, bool)
        for key, _ in HARDWARE_OPTION_LABELS
    }
    connection_behavior = {
        "auto_power_cycle": auto_power_cycle,
        "reset_pin": reset_pin,
        "keep_dtr_inactive": keep_dtr_inactive,
    }
    return base_arguments, option_arguments, hardware_options, connection_behavior


def print_connection_behavior(connection: dict[str, Any]) -> None:
    if connection["auto_power_cycle"]:
        effect = RESET_PIN_LABELS[connection["reset_pin"]]
        if connection["keep_dtr_inactive"]:
            effect += "，DTR 保持无效"
        print(f"自动冷启动：启用，{effect}。")
    else:
        print("自动冷启动：关闭，需要手动给单片机断电再上电。")


def configure_power_cycle(connection: dict[str, Any]) -> None:
    if not connection["auto_power_cycle"] or not connection["keep_dtr_inactive"]:
        return

    from stcgal.protocols import StcBaseProtocol

    original_reset_device = StcBaseProtocol.reset_device

    def reset_device(
        protocol: StcBaseProtocol,
        resetcmd: str | bool = False,
        resetpin: str | bool = False,
    ) -> None:
        protocol.ser.setDTR(False)
        original_reset_device(protocol, resetcmd, resetpin)

    StcBaseProtocol.reset_device = reset_device


def print_hardware_options(options: dict[str, bool], heading: str) -> None:
    print(heading)
    effects = (
        "系统速度：6T（双倍速）" if options["double_speed_6t"]
        else "系统速度：12T（单倍速）",
        "振荡器增益：降低为 1/2 增益，适合 16 MHz 以下"
        if options["reduce_oscillator_gain"]
        else "振荡器增益：不降低，适合 16 MHz 以上",
        "看门狗停止方式：只有 MCU 断电后才停止"
        if options["watchdog_stop_requires_power_cycle"]
        else "看门狗停止方式：任何复位均可停止",
        "内部扩展 RAM：可用" if options["internal_xram_enabled"]
        else "内部扩展 RAM：不可用",
        "下次下载：一并擦除用户 EEPROM"
        if options["erase_eeprom_on_next_download"]
        else "下次下载：保留用户 EEPROM",
        "下载条件：P1.0 和 P1.1 必须同时为低电平"
        if options["require_p1_0_p1_1_low_for_download"]
        else "下载条件：不检测 P1.0 和 P1.1 电平",
        "ALE 引脚：作为 P4.5 口使用" if options["ale_as_p4_5"]
        else "ALE 引脚：保留 ALE 功能",
    )
    for effect in effects:
        print(f"  - {effect}")


def replace_stcgal_option_output() -> None:
    """Replace stcgal's raw STC89 option dump with user-facing effects."""
    from stcgal.options import Stc89Option

    def print_current_options(option_byte: Stc89Option) -> None:
        current_options = {
            "double_speed_6t": option_byte.get_t6(),
            "reduce_oscillator_gain": option_byte.get_clock_gain() == "low",
            "watchdog_stop_requires_power_cycle": option_byte.get_watchdog(),
            "internal_xram_enabled": option_byte.get_xram(),
            "erase_eeprom_on_next_download": option_byte.get_ee_erase(),
            "require_p1_0_p1_1_low_for_download": option_byte.get_pindetect(),
            "ale_as_p4_5": not option_byte.get_ale(),
        }
        print_hardware_options(current_options, "芯片当前硬件选项：")

    Stc89Option.print = print_current_options


def parse_arguments() -> argparse.Namespace:
    default_config = Path(__file__).resolve().parents[1] / "Misc" / "stcgal.toml"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("check", "info", "flash", "flash-with-options"))
    parser.add_argument("--config", type=Path, default=default_config)
    parser.add_argument("--image", type=Path)
    return parser.parse_args()


def main() -> int:
    # Ninja captures child output through a pipe on Windows. Force UTF-8 so
    # Chinese status messages are not encoded with the legacy system code page.
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    sys.stderr.reconfigure(encoding="utf-8", line_buffering=True)
    # Keep status text and stcgal progress on one stream so CLion preserves order.
    sys.stderr = sys.stdout

    arguments = parse_arguments()

    try:
        base_arguments, option_arguments, hardware_options, connection_behavior = load_config(
            arguments.config
        )
    except (OSError, tomllib.TOMLDecodeError, ValueError) as error:
        print(f"Configuration error in {arguments.config}: {error}", file=sys.stderr)
        return 2

    if arguments.action == "check":
        print_connection_behavior(connection_behavior)
        print_hardware_options(
            hardware_options,
            "配置中的硬件选项效果：",
        )
        print("配置检查通过。")
        return 0

    stcgal_arguments = [*base_arguments]
    print_connection_behavior(connection_behavior)
    if arguments.action == "info":
        print("读取芯片型号、时钟、BSL 版本和当前硬件选项。")
    elif arguments.action == "flash":
        print("下载用户程序，并保留芯片当前硬件选项。")
    if arguments.action == "flash-with-options":
        print("下载用户程序，并写入以下硬件选项：")
        print_hardware_options(
            hardware_options,
            "硬件选项效果：",
        )
        stcgal_arguments += option_arguments

    if arguments.action in {"flash", "flash-with-options"}:
        if arguments.image is None:
            print("--image is required for flashing", file=sys.stderr)
            return 2
        image = arguments.image.resolve()
        if not image.is_file():
            print(f"Firmware image not found: {image}", file=sys.stderr)
            return 2
        stcgal_arguments.append(str(image))

    from stcgal.frontend import cli as stcgal_cli

    replace_stcgal_option_output()
    configure_power_cycle(connection_behavior)

    original_argv = sys.argv
    try:
        sys.argv = ["stcgal", *stcgal_arguments]
        return int(stcgal_cli() or 0)
    finally:
        sys.argv = original_argv


if __name__ == "__main__":
    raise SystemExit(main())
