var cmds = []
var codes = []
var text = `
[addi x1, x0, 5  ]      # x1 = 5
[addi x2, x0, 3  ]      # x2 = 3
[add  x3, x1, x2 ]      # x3 = 8
[addi x4, x0, 8  ]      # x4 = 8
[sub  x1, x3, x4 ]      # x1 = 0，验证加法结果
[addi x1, x0, 10 ]      # x1 = 10
[sub  x3, x1, x2 ]      # x3 = 7
[addi x4, x0, 7  ]      # x4 = 7
[sub  x1, x3, x4 ]      # x1 = 0，验证减法结果
[addi x1, x0, 12 ]      # x1 = 12 (0b1100)
[addi x2, x0, 10 ]      # x2 = 10 (0b1010)
[and  x3, x1, x2 ]      # x3 = 8  (0b1000)
[addi x4, x0, 8  ]      # x4 = 8
[sub  x1, x3, x4 ]      # x1 = 0，验证AND结果
[addi x1, x0, 12 ]      # x1 = 12 (0b1100)
[or   x3, x1, x2 ]      # x3 = 14 (0b1110)
[addi x4, x0, 14 ]      # x4 = 14
[sub  x1, x3, x4 ]      # x1 = 0，验证OR结果
[addi x1, x0, 12 ]      # x1 = 12 (0b1100)
[xor  x3, x1, x2 ]      # x3 = 6  (0b0110)
[addi x4, x0, 6  ]      # x4 = 6
[sub  x1, x3, x4 ]      # x1 = 0，验证XOR结果
[addi x1, x0, 8  ]      # x1 = 8
[addi x2, x0, 2  ]      # x2 = 2
[sll  x3, x1, x2 ]      # x3 = 32 (左移2位)
[addi x4, x0, 32 ]      # x4 = 32
[sub  x1, x3, x4 ]      # x1 = 0，验证SLL结果
[addi x1, x0, 32 ]      # x1 = 32
[srl  x3, x1, x2 ]      # x3 = 8 (右移2位)
[addi x4, x0, 8  ]      # x4 = 8
[sub  x1, x3, x4 ]      # x1 = 0，验证SRL结果
[addi x1, x0, -32]      # x1 = -32
[sra  x3, x1, x2 ]      # x3 = -8 (算术右移2位)
[addi x4, x0, -8 ]      # x4 = -8
[sub  x1, x3, x4 ]      # x1 = 0，验证SRA结果
[addi x1, x0, -5 ]      # x1 = -5
[addi x2, x0, 5  ]      # x2 = 5
[slt  x3, x1, x2 ]      # x3 = 1 (因为-5 < 5)
[addi x4, x0, 1  ]      # x4 = 1
[sub  x1, x3, x4 ]      # x1 = 0，验证SLT结果
[addi x1, x0, 5  ]      # x1 = 5
[addi x2, x0, 10 ]      # x2 = 10
[sltu x3, x1, x2 ]      # x3 = 1 (因为5 < 10)
[addi x4, x0, 1  ]      # x4 = 1
[sub  x1, x3, x4 ]      # x1 = 0，验证SLTU结果

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
        result += `/*PC->${pc}*/ ${paddedCode}    // [${cmds[i]}]\n`;
    }
    
    return result;
}
console.log(formatAssemblyCode(codes, cmds))