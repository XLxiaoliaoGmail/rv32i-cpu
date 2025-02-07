var cmds = []
var codes = []
var text = `
// ALU Operations Test Program
// Test add, sub, and, or, xor, sll, srl, sra, slt, sltu
00500093    // [addi x1, x0, 5  ]    # x1 = 5
001080b3    // [add  x1, x1, x1 ]    # x1 = x1 + x1 = 10 // 测试 ALU 是否能同时操作同名寄存器
ffb08093    // [addi x1, x0, -5 ]    # x1 = 5
00A00113    // [addi x2, x0, 10 ]    # x2 = 10
002081B3    // [add  x3, x1, x2 ]    # x3 = x1 + x2 = 15
40208233    // [sub  x4, x1, x2 ]    # x4 = x1 - x2 = -5
0020F2B3    // [and  x5, x1, x2 ]    # x5 = x1 & x2 = 0
0021e333    // [or   x6, x3, x2 ]    # x6 = x3 | x2 = 0x0f
0021c3b3    // [xor  x7, x3, x2 ]    # x7 = x3 ^ x2 = 0x05
00209433    // [sll  x8, x1, x2 ]    # x8 = x1 << x2 = 5120
002254b3    // [srl  x9, x4, x2 ]    # x9 = x4 >> x2 = 0x003fffff
40225533    // [sra  x10, x4, x2]    # x10 = x4 >> x2 (arithmetic) = 0xffffffff
0040a5b3    // [slt  x11, x1, x4]    # x11 = (x1 < x4) ? 1 : 0 = 0
0040b633    // [sltu x12, x1, x4]    # x12 = (x1 < x4) ? 1 : 0 (unsigned) = 1

0000006F    // [jal x0, 0]           # 死循环 
`
function extractAssembly(text) {
    const regex = /\[(.*?)\]/g;  // 匹配[]中的内容
    const matches = text.match(regex);
    
    if (!matches) return [];
    
    // 清理提取的文本，去除[]符号
    return matches.map(match => match.replace(/[\[\]]/g, '').trim());
}
cmds = extractAssembly(text)
// 遍历每个命令
cmds.forEach(cmd => {
    // 创建新的指令对象
    const inst = new Instruction(cmd, {
        ABI: abiParameter.checked,
        ISA: COPTS_ISA[isaParameter.value]
    });
    
    // 将十六进制代码存入数组
    codes.push(inst.hex);
});
console.log(codes)
function formatAssemblyCode(codes, cmds) {
    let result = '';
    
    // 确保codes和cmds长度相同
    if (codes.length !== cmds.length) {
        console.error('codes和cmds数组长度不匹配');
        return '';
    }
    
    // 遍历并拼接格式
    for (let i = 0; i < codes.length; i++) {
        // 计算PC值（每条指令占4字节，所以每次增加4）
        const pc = (i * 4).toString(16).padStart(8, '0');
        
        // 补齐8位十六进制代码
        const paddedCode = codes[i].padStart(8, '0');
        
        // 拼接格式：PC值 + 十六进制代码 + 4个空格 + // + 方括号内的汇编代码
        result += `/* #${pc} */ ${paddedCode}    // [${cmds[i]}]\n`;
    }
    
    return result;
}
console.log(formatAssemblyCode(codes, cmds))